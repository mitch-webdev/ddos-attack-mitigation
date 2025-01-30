#!/bin/bash

# This script helps us look into Apache access logs in case of DDOS attack. We are looking for several requests that are getting either 400 or 408 status code.
# We then get a list of the IP addresses having the most requests (from 2000 in one day) and we add them to ipset and iptables rule to block it.

# Source config file for easy customization

source /path/to/config

# Logging

log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

log_message "Started script execution..."

# Get today's date from logs
TODAY=$(date +"%d/%b/%Y")

# Create ipset

if ! ipset list "$IPSET_NAME" &>/dev/null
then
	ipset create "$IPSET_NAME" hash:net
	log_message "Created ipset ${IPSET_NAME}"
else
	log_message "ipset ${IPSET_NAME} already exists"
fi

# Retry function

retry_request() {
	local ip=$1
	local retries=3
	local delay=5
	local attempt=1
	local response

	while [ $attempt -le $retries ]
	do
		response=$(curl -s "https://api.bgpview.io/ip/$ip")
		if echo "$response" | jq empty > /dev/null 2>&1
		then
			echo "$response"
			return 0
		else
			log_message "Attempt ${attempt} failed for IP: $ip"
			sleep $delay
			((attempt++))
		fi
	done

	return 1
}

# Extract IPs with status codes 400 or 408, count occurrences, and sort the results
# We then go loop through each IP that has more than REQUEST_COUNT and get the network id

grep -h "$TODAY" "$LOG_DIR"/*access.log* | awk '($9 == "400" || $9 == "408") {print $1}' | sort | uniq -c | sort -n | awk '{if ($1 > '"$REQUEST_COUNT"') print $1, $2}' | while read -r count ip

do
	response=$(retry_request "$ip")
	if [ $? -eq 0 ]
	then
		NETWORK=$(echo "$response" | jq -r '.data.prefixes[0].prefix')
		if [[ -n "$NETWORK" ]]
		then
			if ! ipset test "$IPSET_NAME" "$NETWORK" &>/dev/null
			then
				ipset add "$IPSET_NAME" "$NETWORK" # Here we block the network by adding it to the ipset
				log_message "Added ${NETWORK} to ipset ${IPSET_NAME}"
			else
				log_message "Network ${NETWORK} is already in ipset ${IPSET_NAME}"
			fi
		else
			log_message "No network found for this IP: ${ip}"
		fi
	else
		log_message "Failed to get response after retries for IP: $ip"
	fi
	
	sleep 1
done

log_message "Script execution completed."
