# Demo runbook: PDF Section 8, steps 1–8 (Phase 1)

**Before the slot (Mac 1):**
```bash
cd ~/Desktop/cn/cn-project-teamepicrouter
mac1/start-dnsmasq.sh                      # sudo, background
nginx -s reload 2>/dev/null || nginx       # no sudo
tail -f evidence/B-dns/dnsmasq-log.txt     # keep this window visible: shows each query + client IP
```
**Before the slot (Mac 2):** two windows: `python3 backend/server.py A 3001` and `python3 backend/server.py B 3002`.
Then `mac1/check.sh` on Mac 1 must print PASS for A–F.

Use Apple's `/usr/bin/curl` on both Macs (it trusts the Keychain). Never `-k`.

| # | Step | Who / where | Command or action | Point at |
|---|---|---|---|---|
| 1 | Topology + IP/service inventory | any screen | open `docs/architecture.md` (mermaid diagram + IP table) | roles, IPs, ports, cloud equivalents |
| 2 | Both machines on the LAN | Mac 1 and Mac 2 | Mac 1: `ipconfig getifaddr en0; ping -c 3 10.7.2.167`. Mac 2: `ipconfig getifaddr en0; ping -c 3 10.7.5.47` | same /19 subnet, 0% loss |
| 3 | Resolve the private name | Mac 2 | `dig app.teamepicrouter.test` | `ANSWER … 10.7.5.47`, `SERVER: 10.7.5.47#53`; new line in Mac 1's dnsmasq log `from 10.7.2.167` |
| 4 | Open over HTTPS by name | Mac 2 | Safari → `https://app.teamepicrouter.test` (padlock) and `/usr/bin/curl -v https://app.teamepicrouter.test/api/status` | `SSL certificate verify ok`, no warnings, no IP in URL |
| 5 | Load balancing | Mac 2 | `for i in 1 2 3 4 5 6; do /usr/bin/curl -s -D - -o /dev/null https://app.teamepicrouter.test/api/status \| grep -i x-backend; done` | A, B, A, B…; backend windows show `from 10.7.5.47 (real client 10.7.2.167)` |
| 6 | Wireshark evidence | Mac 1 | open `evidence/G-wireshark/G-full-request.pcap` in Wireshark, use filters from `evidence/G-wireshark/HOW-TO-READ.md` | DNS query/response, SYN/SYN-ACK/ACK, ClientHello/ServerHello/Certificate, encrypted App Data on 443 vs readable HTTP on 3001/3002 |
| 7 | Headers + caching | Mac 2 | `/usr/bin/curl -sI https://app.teamepicrouter.test/` then `/usr/bin/curl -sI -H 'If-None-Match: "917dfeb582d632d8"' https://app.teamepicrouter.test/` | `cache-control: public, max-age=60`, `etag`, then `HTTP/2 304` |
| 8 | Fail one backend | Mac 2 | Ctrl+C the Backend A window, rerun the step 5 loop | only `x-backend: B`, all `200`, no errors; restart A afterwards |

## Failure demos (Section 6.3): Mac 2 runs `mac2/7-failures.sh`, it pauses for these

| # | Mac 1 action | Restore |
|---|---|---|
| 1 Wrong DNS server | nothing (Mac 2 switches itself to 1.1.1.1) | automatic |
| 2 DNS → wrong IP | `mac1/start-dnsmasq.sh wrong-ip` (both names → 10.7.2.167) | `mac1/start-dnsmasq.sh` |
| 3 One backend down | nothing (Mac 2 Ctrl+C's Backend A) | Mac 2 restarts A |
| 4 Both backends down | nothing (Mac 2 Ctrl+C's both) | Mac 2 restarts both |
| 5 Wrong port | nothing (Mac 2 curls :8443) | nothing |

## If something breaks: diagnose in layer order

1. **Link/IP:** `ping` the other Mac. Fails → same Wi-Fi? Mac asleep? `arp -n <ip>` shows `(incomplete)` = other Mac not on the network.
2. **DNS:** `dig @10.7.5.47 app.teamepicrouter.test`. Times out → dnsmasq not running (`pgrep -fl dnsmasq`) or Mac 1 firewall.
3. **TCP port:** `nc -vz 10.7.5.47 443` (edge), `nc -vz 10.7.2.167 3001` (backend). Refused → service not running on that port.
4. **TLS:** `/usr/bin/curl -v https://app.teamepicrouter.test/` → cert error = name/trust problem (Keychain, wrong name).
5. **Application:** `502` = nginx is fine but no backend answers; check the backend windows.

## If the IPs change

1. `dns/dnsmasq.conf`: Mac 1's IP in **3 places** (`listen-address`, 2× `address=`) → `mac1/start-dnsmasq.sh`
2. `nginx/teamepicrouter.conf`: Mac 2's IP in the **2 upstream `server` lines** → `cp nginx/teamepicrouter.conf /opt/homebrew/etc/nginx/servers/ && nginx -t && nginx -s reload`
3. `MAC1=` / `MAC2=` at the top of `mac1/check.sh`, `mac1/start-dnsmasq.sh` (wrong-ip line) and every `mac2/*.sh`
4. Mac 2: rerun `mac2/3-use-team-dns.sh` (sets DNS to Mac 1's new IP)
5. Flush caches: Mac 2 `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`, then `mac1/check.sh`
