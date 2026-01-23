# Bitwarden on Google Cloud Docker Image - Countryblock

Docker container that blocks IPs from specified countries from accessing the host, by using `iptables`. Used in the [Bitwarden self-hosted on Google Cloud for Free](https://github.com/dadatuputi/bitwarden_gcloud) project, however this image may be used stand-alone.

# Container Requirements

- Capabilities (`cap_add`):
  - `NET_ADMIN`
  - `NET_RAW`
- `privileged: true`
- `network_mode: "host"`

# Environmental Variables

| Environmental Variable | Description                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------- |
| COUNTRIES              | Space separated list of countries' ISO 3166-1 alpha-2 code (e.g., CN HK AU)               |
| COUNTRYBLOCK_SCHEDULE  | Cron expression for when to update the IP block list (e.g., 0 0 \* \* \*)                 |
| IPTABLES               | Command to use for iptables (e.g. `iptables`, `iptables-legacy`). Defaults to `iptables`. |
| TZ                     | Timezone, optional                                                                        |

# Migration from iptables-legacy

The container automatically handles migration between `iptables-legacy` and `iptables` (nf_tables). When the container starts:

- If no `IPTABLES` environment variable is set, it auto-detects which implementation is in use on your host
- It automatically cleans up any conflicting rules from the other implementation
- This ensures seamless migration without manual intervention

If you prefer to explicitly set which implementation to use, you can set the `IPTABLES` environment variable to either `iptables` or `iptables-legacy`.
