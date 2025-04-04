# Apache DDoS Attack Mitigation Script

## Overview

This script helps detect and mitigate potential DDoS attacks targeting an Apache web server on a RedHat based system. It will also work for Debian based systems but will require a few adjustments. It analyzes access logs for a high volume of requests that return HTTP status codes `400` or `408`, extracts the source IPs, retrieves their network prefixes using the [BGPView API](https://api.bgpview.io/), and blocks them using `ipset`.

The script is designed for Linux servers running Apache (`httpd`) and utilizes `ipset` for efficient network-level blocking.

## Features

- **Automated Log Analysis**: Scans Apache access logs for IPs with excessive bad requests.
- **Network Identification**: Uses the BGPView API to determine the network prefix of each offending IP.
- **Blocking via `ipset`**: Dynamically adds detected networks to an `ipset` for efficient traffic filtering.
- **Retry Mechanism**: Retries API requests in case of temporary failures.
- **Logging**: Logs important events and errors to a dedicated log file.
- **Rate Limiting Protection**: Implements a delay to prevent excessive API requests.

## Requirements

Before running the script, ensure you have the following installed on your system:

- Linux server with Apache (`httpd`) and log files stored at `/var/log/httpd/`
- `ipset` installed (`dnf install ipset`)
- `jq` (for JSON parsing, install via sudo dnf install jq)
- `curl` (for API requests, usually pre-installed)

## Installation

1. Clone the repository:

   ```
   git clone git@github.com:mitch-webdev/ddos-attack-mitigation.git
   cd ddos-attack-mitigation 
   ```

2. Make the script executable:

   ```
   chmod u+x ddos-mitigation.sh
   ```

3. (Optional) Edit configuration parameters inside `config` to customize behavior.

## Usage

Run the script manually:
`
```
sudo ./ddos_mitigation.sh
```

Or schedule it as a cron job for automated execution (e.g., every 15 minutes)

# Configuration

You can modify the `config` file to change the following parameters:

```
LOG_DIR="/var/log/httpd"                 # Path to Apache logs
REQUEST_COUNT=2000                       # Minimum number of bad requests per unique IP to trigger blocking
IPSET_NAME="ddosattack"                  # Name of the ipset to store blocked networks
LOG_FILE="/path/to/log/ddos_script.log"  # Log file path
```

# How It Works

1. The script scans Apache access logs for status codes **400** and **408**.

2. It counts occurrences of each offending IP.

3. If an IP exceeds `REQUEST_COUNT`, the script queries BGPView API to get the associated network prefix.

4. The network prefix is added to the ipset blocklist to prevent further attacks.

5. Logging ensures transparency and debugging support.

# Logs

All important actions are logged to the log file specified in `config`. You can monitor log entries with:

`tail -f /path/to/log/ddos_script.log`

# Unblocking an IP/Network

To remove a network from the blocklist, use:

`sudo ipset del ipsetname 192.168.1.0/24`

To flush all blocked IPs:

`sudo ipset flush ipsetname`

# Add the IPset to firewall (iptables)

`iptables -I INPUT 9 -m set --match-set block_gptbot src -m comment --comment "Block GPT Bot" -j DROP`

# Author

Developed by **Michael Sunier**. Feel free to contribute by submitting pull requests or reporting issues.
