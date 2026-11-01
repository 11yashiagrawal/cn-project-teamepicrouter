# Abhijeet — Mac 1 / node-1

**Enrollment:** 2401010013 · **Machine:** Mac 1 → `node-1` · **Address:** `172.31.250.11` (or `10.0.1.11` with a dedicated VPC)

## Role

Infrastructure and automation owner. Builds the four-machine private network with Terraform, installs and converges every service, and runs the primary DNS server that the other machines use.

- Terraform: VPC/subnet, security group, SSH key, four EC2 instances, cloud-init (`infra/`)
- Automation: `Makefile`, `scripts/infra.sh`, `scripts/converge.sh`, `scripts/lib.sh`, `scripts/tmux.sh`
- Primary DNS: dnsmasq on node-1, zone `teamepicrouter.test`
- Client: `dig`, `curl`, `cn-pingall`, `cn-probe`, `cn-info`
- Integration: README, settings, repository layout and release

## What runs on node-1

| Service | Port | Config |
|---|---|---|
| dnsmasq (primary DNS) | udp/53 | `/etc/dnsmasq.d/cn-team.conf` rendered from `config/dnsmasq.conf` |
| test client tools | — | `/usr/local/bin/cn-*` from `node-bin/` |

DNS records:

| Name | Answer |
|---|---|
| `app.teamepicrouter.test` | `172.31.250.12` (edge) |
| `api.teamepicrouter.test` | `172.31.250.12` (edge) |
| `node-1..4.teamepicrouter.test` | `.11`–`.14` |
| anything else | forwarded to the AWS VPC resolver |

## Proof it works

```bash
make up                      # Terraform builds the subnet and all four machines
make converge                # installs and verifies every service
make status                  # addresses and service state

# on node-1
dig +short @172.31.250.11 app.teamepicrouter.test   # -> 172.31.250.12
sudo systemctl status dnsmasq --no-pager
cn-pingall
```

Evidence: [`evidence/dnsmasq-config.txt`](evidence/dnsmasq-config.txt), [`evidence/dig-client.txt`](evidence/dig-client.txt), [`evidence/dig-public.txt`](evidence/dig-public.txt), [`evidence/pingall.txt`](evidence/pingall.txt), [`evidence/inventory.md`](evidence/inventory.md), [`evidence/node-1-topology.txt`](evidence/node-1-topology.txt).

## Viva points

- Why DNS is its own machine: clients must resolve the name before any TLS or HTTP exists. If DNS fails, `curl` reports "could not resolve" and never opens a socket.
- Why the record points at the edge, not at a backend: clients must not know the backend topology; the edge owns balancing and failover.
- Why `local=/teamepicrouter.test/`: the private zone is authoritative here and must never leak to a public resolver.
- Why TTL 30 s: long enough to be realistic, short enough to show record changes in a demo.
- Cloud mapping: node-1 ≈ Route 53 private hosted zone; the VPC resolver ≈ the upstream forwarder.

## Files in this part

```
README.md                  this document
settings.env               the single configuration file for the whole platform
Makefile                   all operator commands
evidence/                  DNS, dig, ping and inventory output
```
