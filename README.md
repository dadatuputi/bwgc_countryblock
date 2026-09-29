# Bitwarden on Google Cloud Docker Image - Countryblock

> **Status:** maintained, but not used on every install path. In
> [bitwarden_gcloud](https://github.com/dadatuputi/bitwarden_gcloud), new
> installs default to a Cloudflare Tunnel, and this container does not run on
> that path: the host accepts no inbound connections for it to filter, and
> Cloudflare's WAF does geographic blocking at the edge instead. It still runs
> on the Caddy path (`docker-compose.yml`), and remains usable stand-alone.

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
| TZ                     | Timezone, optional                                                          |
