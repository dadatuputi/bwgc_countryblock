#!/usr/bin/env bash

# countryblock script for docker
# <scriptname> start will set up iptables and download the specified country ipsets and wait
# until it receives a INT, TERM, or KILL signal, at which time it will clean up iptables
# <scriptname> update will update the ipsets, good for a cron job
# Copyright (C) 2020 Bradford Law
# Licensed under the terms of MIT

LOG=/var/log/block.log
CHAIN=countryblock

if [ -z "$IPTABLES" ]; then
    if iptables-legacy -n -L "$CHAIN" >/dev/null 2>&1; then
        printf "Detected existing %s chain in iptables-legacy. Using iptables-legacy.\n" "$CHAIN" >>$LOG
        IPTABLES=iptables-legacy
    elif iptables-legacy -n -L DOCKER >/dev/null 2>&1; then
        printf "Detected DOCKER chain in iptables-legacy. Using iptables-legacy.\n" >>$LOG
        IPTABLES=iptables-legacy
    else
        IPTABLES=iptables
    fi
fi

# The list of country codes is provided as an environment variable or below
#COUNTRIES=""

printf "Starting blocklist and ipset construction for countries: %b\n" "$COUNTRIES" >>$LOG

cleanup_conflicting_rules() {
    # Clean up rules from the opposite iptables implementation to avoid conflicts
    local other_iptables

    if [ "$IPTABLES" = "iptables" ]; then
        other_iptables="iptables-legacy"
    else
        other_iptables="iptables"
    fi

    # Check if the other iptables implementation has conflicting rules
    if command -v $other_iptables >/dev/null 2>&1; then
        if $other_iptables -n -L $CHAIN >/dev/null 2>&1; then
            printf "Detected conflicting %s chain in %s, cleaning up...\n" "$CHAIN" "$other_iptables" >>$LOG

            # Remove references to countryblock chain
            while $other_iptables -w -D INPUT -j $CHAIN 2>/dev/null; do :; done
            while $other_iptables -w -D DOCKER-USER -j $CHAIN 2>/dev/null; do :; done
            while $other_iptables -w -D FORWARD -j $CHAIN 2>/dev/null; do :; done

            # Flush and delete the chain
            $other_iptables -w -F $CHAIN 2>/dev/null
            $other_iptables -w -X $CHAIN 2>/dev/null

            printf "Cleaned up conflicting %s rules from %s\n" "$CHAIN" "$other_iptables" >>$LOG
        fi
    fi
}

validate_ip_range() {
    local ip_range="$1"
    # Validate CIDR notation (IPv4)
    if [[ "$ip_range" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$ ]]; then
        # Further validate IP address portions
        local ip_addr cidr
        local -a octets # Declare octets as a local array
        IFS='/' read -r ip_addr cidr <<<"$ip_range"
        IFS='.' read -r -a octets <<<"$ip_addr"

        # Validate each octet is between 0 and 255
        for octet in "${octets[@]}"; do
            if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
                return 1
            fi
        done

        # Validate CIDR is between 0 and 32
        if [[ "$cidr" -lt 0 || "$cidr" -gt 32 ]]; then
            return 1
        fi

        return 0
    fi
    return 1
}

process_zone_file() {
    local zonefile="$1"
    local country="$2"

    # Check if file exists and is readable
    if [[ ! -f "$zonefile" ]] || [[ ! -r "$zonefile" ]]; then
        echo "Error: Cannot read zonefile $zonefile" >>$LOG
        return 1
    fi

    # Validate and add each IP range to ipset
    # This prevents injection of malicious or malformed data into ipset
    while IFS= read -r line; do
        if validate_ip_range "$line"; then
            echo "add $country $line"
        fi
    done <"$zonefile" | ipset restore -!
}

setup() {
    # Create chain and RETURN and FORWARD rules
    $IPTABLES -N $CHAIN
    $IPTABLES -A $CHAIN -j RETURN
    $IPTABLES -I INPUT 1 -j $CHAIN
    $IPTABLES -I DOCKER-USER 1 -j $CHAIN

    for country in $COUNTRIES; do

        # Create ipset for each country
        ipset -exist create $country hash:net

        # Create firewall rule for each country
        $IPTABLES -I $CHAIN -m set --match-set $country src,dst -j DROP

        printf "Created rule for country %b\n" "$country" >>$LOG
    done
}

cleanup() {
    # Clean up old rules
    $IPTABLES -w -F $CHAIN
    while $IPTABLES -w -D INPUT -j $CHAIN 2>/dev/null; do :; done
    while $IPTABLES -w -D DOCKER-USER -j $CHAIN 2>/dev/null; do :; done
    while $IPTABLES -w -D FORWARD -j $CHAIN 2>/dev/null; do :; done
    $IPTABLES -w -X $CHAIN

    # Flush ipsets
    for country in $COUNTRIES; do
        # Flush ipset for each country
        ipset -! destroy $country
        ipset -! destroy ${country,,} # include old lower-case ipset name format
        printf "Destroyed ipsets for %b\n" "$country" >>$LOG
    done
}

update() {
    # For each country, download a list of subnets and add to its respective ipset
    # https://askubuntu.com/a/931153/56882 was useful
    for country in $COUNTRIES; do

        # Pull the latest IP set for country
        local zonefile_name="${country,,}-aggregated.zone"
        local zonefile_remote="https://www.ipdeny.com/ipblocks/data/aggregated/${zonefile_name}"
        local zonefile="/tmp/${zonefile_name}"

        if [[ -f "$zonefile" ]]; then
            curl $zonefile_remote -o $zonefile -z $zonefile
        else
            curl $zonefile_remote -o $zonefile
        fi

        printf "Downloaded %b zone file %b to %b\n" "$country" "$zonefile_remote" "$zonefile" >>$LOG

        # Add each IP address from the downloaded list into the ipset
        if [[ -f "$zonefile" ]]; then
            process_zone_file "$zonefile" "$country"
            printf "Added %b subnets to %b ipset\n" "$(wc -l $zonefile)" "$country" >>$LOG
        else
            echo "Error: Zone file $zonefile not found" >>$LOG
        fi
    done

}

if [ "$1" == "start" ]; then
    # Clean up old rules if they exist in case last run crashed
    cleanup
    # Clean up any conflicting rules from the other iptables implementation
    cleanup_conflicting_rules
    setup
    update

    # Sleep indefinitely waiting for SIGTERM
    printf "$0: waiting for SIGINT SIGTERM or SIGKILL to clean up\n" >>$LOG
    trap "cleanup && exit 0" SIGINT SIGTERM SIGKILL
    sleep inf &
    wait

elif [ "$1" == "update" ]; then
    # Update the ipsets and exit
    update
fi
