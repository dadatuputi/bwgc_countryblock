#!/usr/bin/env bash

# countryblock script for docker
# <scriptname> start will set up iptables and download the specified country ipsets and wait
# until it receives a INT, TERM, or KILL signal, at which time it will clean up iptables
# <scriptname> update will update the ipsets, good for a cron job
# Copyright (C) 2020 Bradford Law
# Licensed under the terms of MIT

LOG=/var/log/block.log
CHAIN=countryblock
IPTABLES=iptables-legacy

# The list of country codes is provided as an environment variable or below
# COUNTRIES=

printf "Starting blocklist and ipset construction for countries: %b\n" "$COUNTRIES" >> $LOG

# Reused iptables rules
FORWARD_RULE="FORWARD -j $CHAIN"


setup() {
	# Create chain and RETURN and FORWARD rules
	$IPTABLES -N $CHAIN
	$IPTABLES -A $CHAIN -j RETURN
	$IPTABLES -I $FORWARD_RULE

	for country in $COUNTRIES; do
		COUNTRY_LOWER=${country,,}

		# Create ipset for each country
		ipset -exist create $COUNTRY_LOWER hash:net
		
		# Create firewall rule for each country
		$IPTABLES -I $CHAIN -m set --match-set $COUNTRY_LOWER src -j DROP
	done
	printf "Created %b chain and rules and ipsets for countries %b\n" "$CHAIN" "$COUNTRIES" >> $LOG
	
}

cleanup() {

	# Clean up old rules
	$IPTABLES -D $FORWARD_RULE
	$IPTABLES -F $CHAIN
	$IPTABLES -X $CHAIN

	# Flush ipsets
        for country in $COUNTRIES; do
                COUNTRY_LOWER=`echo "$country" | tr '[:upper:]' '[:lower:]'`
                # Flush ipset for each country
                ipset flush $COUNTRY_LOWER
        done
	printf "Removed %b chain and rules and flushed ipsets\n" "$CHAIN" >> $LOG
}

update() {
	# For each country, download a list of subnets and add to its respective ipset
	# https://askubuntu.com/a/931153/56882 was useful 
	for country in $COUNTRIES; do
		COUNTRY_LOWER=${country,,}
	
		# Pull the latest IP set for country
		ZONEFILE=$COUNTRY_LOWER-aggregated.zone
		wget --no-check-certificate -N https://www.ipdeny.com/ipblocks/data/aggregated/$ZONEFILE
		printf "Downloaded zone file for %b\n" "$country" >> $LOG
	
		# Add each IP address from the downloaded list into the ipset
		for i in $(cat $ZONEFILE ); do ipset -exist -A $COUNTRY_LOWER $i; done
		printf "Added %b subnets to %b ipset\n" "$(wc -l $ZONEFILE)" "$country" >> $LOG

	done

}

if [ "$1" == "start" ]; then
	# Clean up old rules if they exist in case last run crashed
	cleanup
	setup
	update

	# Sleep indefinitely waiting for SIGTERM
	printf "$0: waiting for SIGINT SIGTERM or SIGKILL to clean up\n" >> $LOG
	trap "cleanup && exit 0" SIGINT SIGTERM SIGKILL
	sleep inf &
	wait

elif [ "$1" == "update" ]; then
	# Update the ipsets and exit
	update
fi
