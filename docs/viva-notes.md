# Viva notes, Phase 1 (short answers; learn them, don't read them)

**Why does DNS come before TCP?**
TCP needs a destination IP address to send its first SYN, and the client only knows a name. DNS turns `app.teamepicrouter.test` into `10.7.5.47`, so it must finish first.

**IP address vs port?**
The IP address picks the machine (10.7.5.47 = Mac 1), the port picks the program on it (53 = dnsmasq, 443 = nginx). Mac 2 has one IP but two ports, 3001 and 3002, for two different backends.

**What is the TCP three-way handshake?**
Client sends SYN with its starting sequence number, server answers SYN-ACK with its own, client sends ACK. Both sides now agree on sequence numbers, so lost or out-of-order bytes can be detected and resent.

**What does TLS do, and what does the client verify?**
TLS encrypts the traffic and proves the server's identity. The client checks the certificate is signed by something it trusts (our cert is in the Keychain), that it's in date, and that the name it typed is in the certificate's Subject Alternative Name.

**Why connect to nginx and not Backend A directly?**
nginx is the single entry point: it holds the certificate, spreads load, and skips a dead backend, so the client never needs to know the backend IPs/ports. Talking to A directly means no TLS, no load balancing and no failover.

**Reverse proxy vs load balancer, and what round-robin means**
A reverse proxy receives requests on behalf of servers and forwards them; a load balancer is a reverse proxy that spreads requests across several servers. Round-robin means take turns: A, B, A, B…

**What happens if Backend A goes down?**
nginx's connection to A is refused, it immediately retries the same request on B, and marks A as failed for 10 s (`max_fails=1 fail_timeout=10s`). The client only sees `X-Backend: B` and no errors.

**Why is HTTP unreadable in Wireshark on 443 but readable on 3001/3002?**
Client↔nginx on 443 is wrapped in TLS, so Wireshark only sees encrypted "Application Data". nginx↔backend on 3001/3002 is plain HTTP because TLS ends at nginx, so those packets are readable; `curl -v` is readable because curl is an endpoint that holds the session keys.

**304 vs fresh cache hit vs full request**
Full request: server sends `200` plus the whole body. Fresh cache hit: within `max-age=60` the browser reuses its copy and sends **nothing** on the network. 304: after it expires, the client asks `If-None-Match: <etag>` and the server says "not modified" with no body, saving bandwidth.

**Why `.test` and not `.local`?**
`.test` is reserved (RFC 6761) for testing and never exists on the real internet. `.local` belongs to multicast DNS (Bonjour), so macOS would send those lookups to mDNS instead of our DNS server.

**What are the single points of failure in our two-Mac design, and what would Phase 2 add?**
Mac 1 holds both DNS and the edge, and Mac 2 holds both backends, so either Mac failing takes the service down. Phase 2 adds a backup DNS resolver, a standby nginx that DNS can be cut over to (short TTL), and firewall rules so only nginx can reach the backends.

---

Extra one-liners the faculty often ask:

- **Ephemeral port:** the random high source port (e.g. 54321) the client OS picks for each connection; the server's well-known port is the destination.
- **Why `curl https://10.7.5.47` fails:** the certificate lists names, not that IP, so the name check fails. That's TLS working correctly.
- **SNI:** the hostname inside ClientHello, so one IP can serve certificates for many names.
- **TTL 30:** clients may cache our DNS answer for 30 s before asking again.
- **`X-Forwarded-For`:** nginx adds the real client IP, because the backend's TCP peer is nginx (10.7.5.47), not the client.
