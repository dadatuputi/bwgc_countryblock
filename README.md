# Bitwarden on Google Cloud Docker Image - Countryblock

Docker container that blocks IPs from specified countries from accessing the host, by using `iptables`. Used in the [Bitwarden self-hosted on Google Cloud for Free](https://github.com/dadatuputi/bitwarden_gcloud) project, however this image may be used stand-alone.

# Container Requirements

* Capabilities (`cap_add`):
  * `NET_ADMIN`
  * `NET_RAW`
* `privileged: true`
* `network_mode: "host"`


# Environmental Variables

| Environmental Variable | Description                                                                 |
| ---------------------- | --------------------------------------------------------------------------- |
| COUNTRIES              | Space separated list of countries' ISO 3166-1 alpha-2 code (e.g., CN HK AU) |
| COUNTRYBLOCK_SCHEDULE  | Cron expression for when to update the IP block list (e.g., 0 0 \* \* \*)   |
| IPTABLES               | Command to use for iptables (e.g. `iptables`, `iptables-legacy`). Defaults to `iptables`. |
| TZ                     | Timezone, optional                                                          |

# Migration from iptables-legacy

If you previously used this container with `iptables-legacy` (or if your host system had rules created by `iptables-legacy`), and you are switching to `iptables` (nf_tables), you must clean up the old rules on your host to avoid conflicts.

Run the following commands on your host machine:

\`\`\`bash
# Remove all references to countryblock in INPUT chain
while sudo iptables-legacy -D INPUT -j countryblock 2>/dev/null; do :; done

# Flush and delete the countryblock chain
sudo iptables-legacy -F countryblock 2>/dev/null
sudo iptables-legacy -X countryblock 2>/dev/null
\`\`\`
