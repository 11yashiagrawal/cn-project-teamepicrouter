# Nishant Ranjan Singh — Mac 3 / node-3

**Enrollment:** 2401010301 · **Machine:** Mac 3 → `node-3` · **Address:** `172.31.250.13` (or `10.0.1.13`)

## Role

Backend A owner, with the two redundancy roles from Phase 2: backup DNS and standby edge. Also owns the architecture document that explains the request flow per OSI layer.

- Backend A: Python standard-library HTTP service on `:3001`, returns `X-Backend: A`
- Backup DNS: second dnsmasq with the same zone and records as node-1
- Standby edge: identical nginx configuration and certificate, ready if node-2 fails
- Architecture: `docs/architecture.md` and the OSI mapping

## What runs on node-3

| Service | Port | Config |
|---|---|---|
| Backend A | tcp/3001 | `/opt/cn/backend.py`, unit `backend-a.service` |
| dnsmasq (backup) | udp/53 | `/etc/dnsmasq.d/cn-team.conf` |
| nginx (standby edge) | tcp/80, 443 | `/etc/nginx/conf.d/cn-standby-edge.conf` |

Backend endpoints:

| Path | Behaviour |
|---|---|
| `/` | service info, `Cache-Control: no-store` |
| `/api/status` | `{"backend": "A", ...}`, `Cache-Control: public, max-age=60`, `ETag` |
| `/api/cached` | identical body on A and B, supports `If-None-Match` → 304 |

The backend runs as an unprivileged dynamic user and binds `0.0.0.0` so the edge on node-2 can reach it. It must not bind `127.0.0.1`.

## Proof it works

```bash
# on node-3
sudo systemctl status backend-a --no-pager
curl -i http://172.31.250.13:3001/api/status      # X-Backend: A

# backup DNS answers even when node-1 stops
dig +short @172.31.250.13 app.teamepicrouter.test # -> 172.31.250.12

# standby edge has a valid config
sudo nginx -t
```

Evidence: [`evidence/backend-a.txt`](evidence/backend-a.txt), [`evidence/failover.txt`](evidence/failover.txt), [`evidence/node-3-topology.txt`](evidence/node-3-topology.txt), [`evidence/architecture.md`](evidence/architecture.md).

## Viva points

- **DNS failure vs application failure:** with primary DNS down, clients fall back to node-3 and resolution still succeeds; the failure is invisible at the HTTP layer. With Backend A down, DNS still resolves and the edge retries on B.
- **Why a second resolver:** DNS is a single point of failure otherwise; two resolvers with identical records remove it.
- **Why the standby edge shares the certificate:** a client that already trusts the CA accepts either edge without a new trust decision.
- **Why `max_fails=1 fail_timeout=10s`:** one failed attempt marks a backend down briefly, so traffic moves quickly but recovery is automatic.
- **OSI mapping:** DNS = L7 name resolution over L4 UDP/53; TLS = L5/L6 presentation and session; nginx = L7 proxy; TCP handshake = L4.

## Files in this part

```
README.md               this document
backend.py              Backend A/B source (identical code, different BACKEND_ID and port)
backend-a.service       rendered systemd unit for Backend A
dnsmasq-backup.conf     rendered backup DNS configuration
standby-edge.conf       rendered standby edge configuration
evidence/               backend A, failover, topology and architecture
```
