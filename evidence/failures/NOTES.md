# Section 6.3 failure demos: what we saw and what it proves

Driven by `mac2/7-failures.sh` on Mac 2; Mac 1 steps in `docs/demo-runbook.md`. Each one was restored before the next.

| # | Break | What we observed | What it proves | Evidence |
|---|---|---|---|---|
| 1 | Mac 2's DNS server set to 1.1.1.1 | `dig` → `status: NXDOMAIN` from `SERVER: 1.1.1.1#53` (the real internet has no `.test`); `curl: (6) Could not resolve host`; `ping 10.7.5.47` 0% loss | DNS and IP connectivity are separate layers: the network works, only the name directory is wrong | `1-wrong-dns-server.txt` |
| 2 | Both records → 10.7.2.167 (`mac1/start-dnsmasq.sh wrong-ip`) | `dig +short` → `10.7.2.167` (lookup *succeeds*); `curl: (7) Failed to connect … port 443`: nothing listens on 443 there | DNS is a directory, not a connection: it hands out an address, even a wrong one, and never checks the service | `2-dns-wrong-ip.txt`; Mac 1's dnsmasq log at 19:14:55 shows `config app.teamepicrouter.test is 10.7.2.167` |
| 3 | Backend A stopped (Ctrl+C) | 6 × `HTTP/2 200 x-backend: B`, no errors. nginx logged `connect() failed (61: Connection refused) while connecting to upstream` once and silently retried on B | nginx retries a refused backend on the healthy one, then skips A for `fail_timeout=10s` | `3-backend-a-stopped.txt`, `nginx-logs-mac1-failures-3-4.txt` |
| 4 | Both backends stopped | DNS ✓, TCP ✓ (`Connected … port 443`), TLS ✓ (`SSL certificate verify ok`, ALPN h2), then `HTTP/2 502` + `502 Bad Gateway` page | The edge (DNS, TCP, TLS, nginx) still works; the failure is behind it, between nginx and the backends | `4-both-backends-stopped.txt`, `nginx-logs-mac1-failures-3-4.txt` |
| 5 | Port 8443 instead of 443 | `curl: (7) … port 8443`; `nc` → 8443 `Connection refused`, 443 `succeeded`; ping 0% loss | The IP address picks the machine, the port picks the program: same host, different port, different result | `5-wrong-port.txt` |

**Layer-by-layer reading** (how we'd diagnose an unknown fault): 1 fails at DNS, 2 fails at TCP (after DNS "worked"),
5 fails at TCP (wrong port), 4 fails at the application/upstream after TLS succeeded, 3 doesn't fail at all thanks to the load balancer.
