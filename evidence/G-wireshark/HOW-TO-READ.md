# How to read `G-full-request.pcap`

Captured on **Mac 2 (10.7.2.167), interface en0** by `mac2/6-capture.sh` during one
`curl -v --http1.1 --tls-max 1.2 https://app.teamepicrouter.test/api/status`.
Capture filter: `host 10.7.5.47 and (port 53 or port 443 or port 3001 or port 3002)`.
TLS 1.2 is forced on purpose: in TLS 1.3 the Certificate message is encrypted, so you couldn't point at it.

**Trimmed to the one request (33 packets, 0.24 s):** the original capture kept running after curl finished and also
recorded Mac 2's unrelated DNS lookups. We kept frames 7–39 with
`editcap -r G-full-request-raw.pcap G-full-request.pcap 7-39` (same as Wireshark's *File → Export Specified Packets*).
Nothing inside the request was changed. Frame map: **1–2** DNS · **3–5** TCP handshake · **6** ClientHello ·
**8** ServerHello + Certificate · **10, 12** ChangeCipherSpec · **14** encrypted request · **16–18** nginx→backend handshake ·
**19** plain `GET /api/status` to :3002 · **21–22** plain `200 OK` + JSON from Backend B · **26** encrypted response · **29–33** close.
`verification.txt` (made by `mac1/check.sh G` with tshark) has one line per item below.

Open it on Mac 1: `open -a Wireshark evidence/G-wireshark/G-full-request.pcap`.
For 3001/3002 to show as HTTP: right-click a packet on 3001 → *Decode As…* → TCP port 3001 → HTTP (same for 3002).

| # | What to show | Wireshark display filter | Point at |
|---|---|---|---|
| 1 | DNS query | `dns.qry.name == "app.teamepicrouter.test" && dns.flags.response == 0` | src 10.7.2.167 : **ephemeral port** → dst 10.7.5.47 : **53/UDP**; Query `A app.teamepicrouter.test` |
| 2 | DNS response | `dns.a == 10.7.5.47` | Answer `A 10.7.5.47`, TTL ≤ 30; same transaction ID as the query; ports reversed |
| 3 | TCP SYN | `tcp.flags.syn == 1 && tcp.flags.ack == 0 && tcp.dstport == 443` | client ephemeral port → 443, **Seq = 0** (relative) |
| 4 | TCP SYN-ACK | `tcp.flags.syn == 1 && tcp.flags.ack == 1 && tcp.srcport == 443` | Seq = 0, **Ack = 1** (server acknowledges the client's SYN) |
| 5 | TCP ACK | `tcp.dstport == 443 && tcp.seq == 1 && tcp.ack == 1 && tcp.len == 0` | Seq = 1, Ack = 1: handshake done, *before* any TLS byte |
| 6 | TLS ClientHello | `tls.handshake.type == 1` | Extension `server_name` = **app.teamepicrouter.test** (SNI), offered cipher suites |
| 7 | TLS ServerHello | `tls.handshake.type == 2` | chosen version TLS 1.2 + one cipher suite |
| 8 | TLS Certificate | `tls.handshake.type == 11` | subject CN / SAN = app.teamepicrouter.test (our self-signed cert) |
| 9 | ChangeCipherSpec | `tls.record.content_type == 20` | sent by both sides: "everything after this is encrypted" |
| 10 | Encrypted data | `tls.record.content_type == 23` | "Application Data": the HTTP request/response, unreadable |
| 11 | Plain HTTP to backend | `tcp.port == 3001 \|\| tcp.port == 3002` (after *Decode As*: `http`) | src **10.7.5.47** (nginx) → 10.7.2.167:3001/3002, readable `GET /api/status`, `X-Forwarded-For: 10.7.2.167`, response `X-Backend` |
| ★ | Whole conversation | `dns \|\| tcp.port == 443 \|\| tcp.port == 3001 \|\| tcp.port == 3002` | read top to bottom: DNS → TCP → TLS → (inside nginx) → HTTP to backend → back |

**Sequence/ack numbers (reliability):** Statistics → Flow Graph shows each Seq/Ack. Every data packet's Ack = the
next byte the receiver expects; a missing Ack would make the sender retransmit. That's TCP reliability.

**Why the HTTP is unreadable on 443 but readable in `curl -v` and on 3001/3002**
On 443, Wireshark is a bystander on the wire: it sees only TLS records encrypted with keys negotiated in the
handshake, which never cross the network. `curl -v` is an endpoint: it prints the HTTP *before* encrypting and
*after* decrypting. nginx terminates TLS and talks plain HTTP to the backends, so the 3001/3002 traffic in the same
capture is readable. That proves exactly where TLS ends.

## Live capture on Mac 1 for the demo

1. Open Wireshark → pick interface **Wi-Fi: en0** (Mac 1 is where DNS and the edge live, so it sees all of it).
   (If it lists no interfaces: install "ChmodBPF" from the Wireshark .dmg, or run `sudo chmod o+r /dev/bpf*` for the session.)
2. Display filter: `dns || tcp.port == 443 || tcp.port == 3001 || tcp.port == 3002`
3. On Mac 2: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` then
   `/usr/bin/curl -v --http1.1 --tls-max 1.2 https://app.teamepicrouter.test/api/status`
4. Stop the capture and walk through rows 1–11 above.
