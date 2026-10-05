# Evidence index: PDF requirement → file

Every `.txt` shows the exact command (`$ …`) above its output. `mac1-*` = run on Mac 1 (10.7.5.47),
`mac2-*` = run on Mac 2 (10.7.2.167). Regenerate Mac 1's files with `mac1/check.sh`.

| PDF task | Requirement | Evidence |
|---|---|---|
| A: LAN | IPv4, mask/prefix, gateway, interface, MAC, per Mac | `A-lan/mac1-ip-and-ping.txt`, `A-lan/mac2-ip-and-ping.txt`, table in `docs/architecture.md` |
| A | Ping both directions, 0% loss | same two files (last lines) |
| A | Topology diagram | `docs/architecture.md` (mermaid) |
| B: DNS | Records app/api → Mac 1 | `dns/dnsmasq.conf`, `B-dns/mac1-resolve.txt` |
| B | ≥ 2 clients resolve through our DNS | Mac 1: `B-dns/mac1-resolve.txt` (`/etc/resolver` + `dscacheutil`); Mac 2: `B-dns/mac2-dig-nslookup.txt` (`SERVER: 10.7.5.47#53`) |
| B | Server sees the queries | `B-dns/dnsmasq-team-queries.txt` (lines `query[A] app.teamepicrouter.test from 10.7.2.167`) |
| C: Backends | `/`, `/api/status`, `X-Backend`, LAN-reachable on 3001/3002 | `C-backends/curl-a-from-mac1.txt`, `C-backends/curl-b-from-mac1.txt`, `backend/server.py` |
| D: Edge + LB | Round-robin A/B by name | `D-loadbalancing/alternation-http-from-mac1.txt` (stage 1, HTTP), `alternation-https-from-mac1.txt`, `mac2-alternation.txt`, `nginx/teamepicrouter.conf` |
| D | Backends see nginx as source, real client in X-Forwarded-For | `D-loadbalancing/screenshot-backend-A-log.png`, `-B-log.png` + `G-wireshark/verification.txt` last two lines |
| E: TLS | Cert for app/api.teamepicrouter.test, made with OpenSSL | `tls/openssl.cnf`, `tls/README.md`, `E-tls/cert-details.txt` |
| E | Verified with no `-k` | `E-tls/curl-v-mac1.txt`, `E-tls/mac2-curl-v.txt`, `E-tls/mac2-trust-cert.txt` |
| E | IP URL fails (name mismatch) | `E-tls/ip-url-fails-mac1.txt`, `E-tls/mac2-ip-url-fails.txt` |
| E | 80 → 443 redirect | `E-tls/redirect-80-to-443-mac1.txt`, `E-tls/mac2-redirect-80.txt` |
| E | HTTP/1.1 vs HTTP/2 | `E-tls/http1-vs-http2-mac1.txt`, `E-tls/mac2-http1-vs-http2.txt` |
| F: Caching | Cache-Control + ETag, 304 from both backends | `F-caching/mac1-full-and-304.txt`, `F-caching/mac2-full-and-304.txt` |
| G: Capture | pcap of DNS → TCP → TLS → HTTP | `G-wireshark/G-full-request.pcap`, `G-wireshark/curl-v-during-capture.txt` |
| G | Each item located (tshark) | `G-wireshark/verification.txt` |
| G | How to read it + filters | `G-wireshark/HOW-TO-READ.md` |
| G | Wireshark GUI screenshots of each item | `G-wireshark/screenshot-1…6-*.png` |
| 6.3 | 5 failure demos + what each proves | `failures/1-…` to `failures/5-…`, `failures/NOTES.md` |

## Manual screenshots still needed

- [x] **Browser padlock → certificate** on Mac 2 (Chrome, no warning) → `E-tls/screenshot-mac2-chrome-cert-general.png`, `screenshot-mac2-chrome-cert-details.png`
- [x] **Keychain trust** "Always Trust": Mac 1 → `E-tls/screenshot-mac1-keychain-trust.png` (+ `-san.png` showing the SANs), Mac 2 → `E-tls/screenshot-mac2-keychain-trust.png`
- [x] **Browser DevTools cache** on Mac 2: document `304` over `h2` → `F-caching/screenshot-mac2-devtools-304.png`
- [x] **Backend windows** on Mac 2 showing `[A] from 10.7.5.47 (real client 10.7.2.167)` and `[B] …` → `D-loadbalancing/screenshot-backend-A-log.png`, `screenshot-backend-B-log.png`
- [x] **Wireshark GUI** (Mac 1, `G-full-request.pcap`) → `G-wireshark/`: `screenshot-1-dns-response-frame2.png` (A 10.7.5.47, TTL 30, UDP 53), `screenshot-2a/2b/2c-tcp-syn/synack/ack-frame3-5.png` (Seq/Ack 0→0,1→1,1), `screenshot-3-tls-clienthello-sni-frame6.png`, `screenshot-4-tls-certificate-frame8.png`, `screenshot-5a/5b-tls-appdata-*.png` (encrypted), `screenshot-6-plain-http-to-backend-frame19.png` (readable GET + X-Forwarded-For)
- [ ] **dnsmasq log** live window (`tail -f evidence/B-dns/dnsmasq-log.txt`) showing a query `from 10.7.2.167` → `B-dns/screenshot-dnsmasq-log.png`
