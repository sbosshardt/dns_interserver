# dns_interserver – Interserver DNS API hook for acme.sh

This repository contains `dns_interserver.sh`, a POSIX shell script that adds DNS‐01 automation for domains hosted on Interserver's DNS service to the acme.sh client.

Built and tested on: acme.sh 3.0.8 + Alpine BusyBox sh
* Rest API: https://my.interserver.net/apiv2

## Quick start

### Features
* Create/remove TXT records via INTERSERVER api
* Works with wildcard and multi-SAN certs
* NO external dependencies: `curl` only

CONFIG requires: bash or POSIX sh; curl; INTERSERVER_API_KEY in env.

## Install

```
# clone
git clone https://github.com/sbosshardt/dns_interserver.git
cd dns_interserver

cd dns_interserver.sh ~/.acme.sh/dnsapi/
chmod 700 ../.acme.sh/dnsapi/dns_interserver.sh
```

## Usage
```
export INTERSERVER_API_KEY="yourKey"
acme.sh --issue --dns dns_interserver -d example.com -d '*.example.com'
```

## License
MIT License - see LICENSE file

Tested on April 19, 2025.
