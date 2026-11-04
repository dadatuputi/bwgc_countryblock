#!/usr/bin/env bash

# countryblock script for docker
# <scriptname> start will set up iptables and download the specified country ipsets and wait
# until it receives a INT, TERM, or KILL signal, at which time it will clean up iptables
# <scriptname> update will update the ipsets, good for a cron job
# Copyright (C) 2020 Bradford Law
# Licensed under the terms of MIT

LOG=/var/log/block.log
CHAIN=countryblock
# Returns the iptables backend the host is using. Docker creates its own chains
# in whichever backend is live, so their presence identifies it. Rules written
# to the other backend are accepted but never consulted.
#
# Set IPTABLES to override.
detect_iptables() {
    if [ -n "${IPTABLES:-}" ]; then
        printf '%s' "$IPTABLES"
        return
    fi
    for candidate in iptables-nft iptables-legacy; do
        if command -v "$candidate" >/dev/null 2>&1 \
           && "$candidate" -S 2>/dev/null | grep -q '^-N DOCKER'; then
            printf '%s' "$candidate"
            return
        fi
    done
    # No Docker chains in either backend; fall back rather than guess.
    printf 'iptables-legacy'
}

IPTABLES=$(detect_iptables)

# The list of country codes is provided as an environment variable or below
#COUNTRIES=""

printf "Starting blocklist and ipset construction for countries: %b\n" "$COUNTRIES" >> $LOG
printf "Using iptables backend: %b\n" "$IPTABLES" >> $LOG

# The jump that sends traffic into our chain, from INPUT and DOCKER-USER.
#
# INPUT only sees traffic addressed to the host itself. Traffic to a port
# published by a container on a bridge network is DNATed and routed through
# FORWARD, so it never reaches INPUT. Docker passes that traffic through
# DOCKER-USER first, the chain it reserves for user rules and never flushes.
#
# A rule spec with no position: -I takes a position, -D does not. Combining
# them ("-D INPUT 1 -j countryblock") is a syntax error that exits 2 without
# removing anything.
JUMP_SPEC="-j $CHAIN"
JUMP_POSITION=1

validate_ip_range() {
    local ip_range="$1"
    # Validate CIDR notation (IPv4)
    if [[ "$ip_range" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$ ]]; then
        # Further validate IP address portions
        local ip_addr cidr
        local -a octets  # Declare octets as a local array
        IFS='/' read -r ip_addr cidr <<< "$ip_range"
        IFS='.' read -r -a octets <<< "$ip_addr"
        
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
        echo "Error: Cannot read zonefile $zonefile" >> $LOG
        return 1
    fi
    
    # Validate each line, then add all the valid ones with a single
    # "ipset restore". Running "ipset add" per line forks a process per
    # subnet, which is slow for countries with thousands of them.
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # A subnet contains no whitespace, so strip all of it, including the
        # \r of a CRLF file.
        line="${line//[[:space:]]/}"

        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        if validate_ip_range "$line"; then
            echo "add $country $line"
        else
            echo "Invalid IP range found: $line" >> $LOG
        fi
    done < "$zonefile" | ipset restore -exist || {
        # ipset reports the offending line on stderr. Lines before it were
        # still added.
        echo "Error adding IP ranges from $zonefile to set $country" >> $LOG
        return 1
    }
}

# Earlier versions always wrote to iptables-legacy, and forks of this image
# have used iptables-nft. When detection picks one backend, a chain left in the
# other is not removed by cleanup. The kernel evaluates both backends, so that
# chain keeps dropping whatever countries it was last given, and its references
# to the country ipsets stop cleanup from destroying them.
cleanup_other_backend() {
    local other parent
    for other in iptables-nft iptables-legacy; do
        # An IPTABLES override such as plain "iptables" is one of these two
        # under another name. Removing our chain from the active backend here
        # is harmless: this only runs at start, before cleanup and setup.
        [ "$other" = "$IPTABLES" ] && continue
        command -v "$other" >/dev/null 2>&1 || continue
        # Listing legacy rules loads its kernel modules and registers empty
        # tables, after which every iptables-nft command on the host warns
        # that legacy tables are present. Only look once legacy is in use.
        if [ "$other" = iptables-legacy ] \
           && ! grep -qx filter /proc/net/ip_tables_names 2>/dev/null; then
            continue
        fi
        $other -S $CHAIN >/dev/null 2>&1 || continue

        printf "Removing stale %b chain from %b\n" "$CHAIN" "$other" >> $LOG
        for parent in INPUT DOCKER-USER; do
            while $other -C $parent $JUMP_SPEC 2>/dev/null; do
                $other -D $parent $JUMP_SPEC || break
            done
        done
        $other -F $CHAIN
        $other -X $CHAIN
    done
}

setup() {
    # Create the chain if it is not already there.
    $IPTABLES -N $CHAIN 2>/dev/null || true
    $IPTABLES -C $CHAIN -j RETURN 2>/dev/null || $IPTABLES -A $CHAIN -j RETURN

    # Insert the jump only when it is absent. Without the -C guard every
    # container start adds another copy.
    if ! $IPTABLES -C INPUT $JUMP_SPEC 2>/dev/null; then
        $IPTABLES -I INPUT $JUMP_POSITION $JUMP_SPEC
    fi

    # DOCKER-USER exists only once Docker has set up its rules in this
    # backend. Without it there is no container traffic to filter here.
    if ! $IPTABLES -S DOCKER-USER >/dev/null 2>&1; then
        printf "No DOCKER-USER chain in %b, container traffic is not filtered\n" "$IPTABLES" >> $LOG
    elif ! $IPTABLES -C DOCKER-USER $JUMP_SPEC 2>/dev/null; then
        $IPTABLES -I DOCKER-USER $JUMP_POSITION $JUMP_SPEC
    fi

    for country in $COUNTRIES; do

        # Create ipset for each country
        ipset -exist create $country hash:net
        
        # Create firewall rule for each country
        $IPTABLES -I $CHAIN -m set --match-set $country src,dst -j DROP

        printf "Created rule for country %b\n" "$country" >> $LOG
    done
}

cleanup() {
    # Remove every jump: -X refuses to delete a chain that is still referenced,
    # and duplicates accumulate if any are left.
    removed=0
    while $IPTABLES -C INPUT $JUMP_SPEC 2>/dev/null; do
        $IPTABLES -D INPUT $JUMP_SPEC || break
        removed=$((removed + 1))
    done
    if [[ $removed -gt 1 ]]; then
        printf "Removed %d duplicate %b jumps left by earlier runs\n" "$removed" "$CHAIN" >> $LOG
    fi
    # -C fails when DOCKER-USER does not exist, so this is a no-op there.
    while $IPTABLES -C DOCKER-USER $JUMP_SPEC 2>/dev/null; do
        $IPTABLES -D DOCKER-USER $JUMP_SPEC || break
    done

    $IPTABLES -F $CHAIN 2>/dev/null || true
    $IPTABLES -X $CHAIN 2>/dev/null || true

    # Flush ipsets
    for country in $COUNTRIES; do
        # Flush ipset for each country
        ipset -! destroy $country
        ipset -! destroy ${country,,} # include old lower-case ipset name format
        printf "Destroyed ipsets for %b\n" "$country" >> $LOG
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
        local partfile="${zonefile}.part"

        # --fail: an HTTP error (404 for an unknown country code) must fail
        # rather than save the error page as the zone file.
        # Downloading to a separate file keeps the last good copy when the
        # download fails, so the ipset is still rebuilt from it on start.
        # -z skips the transfer when that copy is current; curl leaves the
        # output file uncreated then. It warns when its file is missing, so it
        # is only passed once there is one. --remote-time dates the file with
        # the server's Last-Modified, which is what -z compares against.
        local -a curl_opts=(--fail --silent --show-error --location --retry 3 --remote-time -o "$partfile")
        [[ -f "$zonefile" ]] && curl_opts+=(-z "$zonefile")

        rm -f "$partfile"
        if ! curl "${curl_opts[@]}" "$zonefile_remote"; then
            printf "Error: could not download %b zone file %b, keeping the previous one\n" "$country" "$zonefile_remote" >> $LOG
        elif [[ -f "$partfile" ]]; then
            mv "$partfile" "$zonefile"
            printf "Downloaded %b zone file %b to %b\n" "$country" "$zonefile_remote" "$zonefile" >> $LOG
        else
            printf "%b zone file %b is unchanged\n" "$country" "$zonefile" >> $LOG
        fi
        rm -f "$partfile"

        # Add each IP address from the downloaded list into the ipset
        if [[ -f "$zonefile" ]]; then
            process_zone_file "$zonefile" "$country"
            printf "Added %b subnets to %b ipset\n" "$(wc -l $zonefile)" "$country" >> $LOG
        else
            echo "Error: Zone file $zonefile not found" >> $LOG
        fi
    done

}

if [ "$1" == "start" ]; then
    # Clean up old rules if they exist in case last run crashed. The other
    # backend goes first so the ipsets it references can then be destroyed.
    cleanup_other_backend
    cleanup
    setup
    update

    # Sleep indefinitely waiting for SIGTERM
    printf "$0: waiting for SIGINT or SIGTERM to clean up\n" >> $LOG
    trap "cleanup; exit 0" SIGINT SIGTERM EXIT
    sleep inf &
    wait

elif [ "$1" == "update" ]; then
    # Update the ipsets and exit
    update
fi
