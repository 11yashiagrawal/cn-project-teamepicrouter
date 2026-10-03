# CN Project: Private Network Service Platform (Team Epic Router)

Phase 1 of the Computer Networks course project: a client types **`https://app.teamepicrouter.test`**, the name is
resolved by **our own DNS server**, the request reaches **our nginx edge** over **TLS**, and is load-balanced
**round-robin** to one of **two backends**, with packet-level evidence for every step.
Built on **two Macs with combined roles** (PDF "Type 2"). Everything is local; no cloud.

**Team Epic Router** · Computer Networks, Section D · Phase 1

| Member | Enrollment no. | Role |
|---|---|---|
| Abhijeet &lt;Surname&gt; | 24XXXXXXXX | Mac 1: private DNS (dnsmasq) + nginx edge (reverse proxy, load balancer, TLS) |
| Yashi Agrawal | 2401020078 | Mac 2: Backend A + Backend B, test client, packet capture |
| Nishant &lt;Surname&gt; | 24XXXXXXXX | Architecture document |
| Prashant &lt;Surname&gt; | 24XXXXXXXX | GitHub repo + evidence |

| Mac | Owner | IP | Runs | Ports |
|---|---|---|---|---|
| Mac 1 | Abhijeet | 10.7.5.47 | dnsmasq (private DNS) + nginx (reverse proxy, round-robin LB, TLS termination) | 53, 80 → 443 |
| Mac 2 | Yashi | 10.7.2.167 | Backend A + Backend B (`backend/server.py`), main test client, packet capture | 3001, 3002 |

`app.teamepicrouter.test` and `api.teamepicrouter.test` → **10.7.5.47** (Mac 1, where nginx runs).

- Architecture, IP table, request flow per layer, cloud equivalents: [`docs/architecture.md`](docs/architecture.md)
- Evidence for every PDF requirement: [`evidence/INDEX.md`](evidence/INDEX.md)
- Demo steps (PDF Section 8) and troubleshooting: [`docs/demo-runbook.md`](docs/demo-runbook.md)
- Viva answers: [`docs/viva-notes.md`](docs/viva-notes.md)

## Repo map

| Path | What |
|---|---|
| `dns/dnsmasq.conf` | DNS records + forwarding |
| `nginx/teamepicrouter.conf` | edge: 80 → 301, 443 TLS + HTTP/2, upstream round-robin |
| `backend/server.py` | the backend (stdlib Python; same code runs as A or B) |
| `tls/` | `openssl.cnf`, the **public** certificate, exact commands. The private key is never in git |
| `mac1/` | `start-dnsmasq.sh`, `check.sh` (re-runs every check from Mac 1, saves evidence, prints PASS/FAIL) |
| `mac2/` | Yashi's kit: numbered scripts + [`README`](mac2/README.md) |
| `evidence/` | outputs, pcap, screenshots |

## Start everything

**Mac 1** (Homebrew: `brew install dnsmasq nginx`; Wireshark app for tshark):
```bash
cd ~/Desktop/cn/cn-project-teamepicrouter
# once: per-domain resolver + trust the cert (sudo)
sudo mkdir -p /etc/resolver && echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/teamepicrouter.test
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain tls/app.teamepicrouter.test.crt
# once: certificate + key (see tls/README.md), nginx config
cp nginx/teamepicrouter.conf /opt/homebrew/etc/nginx/servers/
# every session
mac1/start-dnsmasq.sh                  # sudo; runs in background, logs to evidence/B-dns/dnsmasq-log.txt
nginx -t && (nginx -s reload 2>/dev/null || nginx)
mac1/check.sh                          # PASS/FAIL for tasks A–G
```
Mac 1 deliberately does **not** use dnsmasq as its system-wide DNS: `/etc/resolver/teamepicrouter.test` sends only our
domain to it, so Mac 1 keeps the internet if dnsmasq stops. (macOS `dig` ignores `/etc/resolver`; use `dig @127.0.0.1`.)

**Mac 2: run the backends** (Python 3 standard library only, nothing to install). Two Terminal windows, from the repo folder:
```bash
python3 backend/server.py A 3001     # window 1 -> Backend A
python3 backend/server.py B 3002     # window 2 -> Backend B
```
Both listen on `0.0.0.0` (all interfaces), so nginx on Mac 1 can reach them. Click **Allow** if macOS asks about incoming
connections. Quick check from any machine: `curl -i http://10.7.2.167:3001/api/status` → `X-Backend: A`
(on a single computer: `curl -i http://127.0.0.1:3001/api/status`).
Endpoints: `GET /` (cacheable: `Cache-Control: public, max-age=60` + `ETag`, answers `304` to `If-None-Match`),
`GET /api/status` (`{"backend": "A", "status": "ok"}`, `Cache-Control: no-store`). Every response carries `X-Backend: A|B`.

Then follow [`mac2/README.md`](mac2/README.md): scripts 1 → 7.

**Stop:** Mac 1 `sudo pkill dnsmasq; nginx -s stop`. Mac 2 Ctrl+C both backends, `mac2/undo-dns.sh`.

## If the IPs change
See the end of [`docs/demo-runbook.md`](docs/demo-runbook.md): Mac 1's IP is in 3 places in `dns/dnsmasq.conf`,
Mac 2's IP in the 2 upstream lines of `nginx/teamepicrouter.conf`, plus the `MAC1=`/`MAC2=` lines in the scripts.
