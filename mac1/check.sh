#!/bin/bash
# Re-runs every Phase 1 check that can be done from Mac 1 (Abhijeet),
# saves the output into evidence/, and prints PASS/FAIL per task.
#   mac1/check.sh          -> all tasks
#   mac1/check.sh B E      -> only tasks B and E
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
MAC2=10.7.2.167
APP=app.teamepicrouter.test
CURL=/usr/bin/curl   # Apple's curl: reads the macOS Keychain (Anaconda's curl does not)
TSHARK=/Applications/Wireshark.app/Contents/MacOS/tshark

# Print "$ command" then its output, so every evidence file shows what was run.
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }
result() { [ "$2" = 0 ] && echo "PASS  $1" || echo "FAIL  $1"; }
stamp() { echo "# Mac 1 (Abhijeet, $MAC1) - $(date '+%Y-%m-%d %H:%M:%S')"; echo; }

A() {
  f=evidence/A-lan/mac1-ip-and-ping.txt
  # Wake-up ping (not recorded): Mac 2's Wi-Fi power-save + ARP lookup often drop the very first packet.
  ping -c 1 -t 3 $MAC2 >/dev/null
  { stamp
    run "networksetup -listallhardwareports | grep -A2 'Wi-Fi'"
    run ipconfig getifaddr en0
    run ipconfig getoption en0 subnet_mask
    run "route -n get default | grep -E 'gateway|interface'"
    run "ifconfig en0 | grep -E 'ether|inet '"
    run ping -c 4 $MAC2
  } > $f
  grep -q ' 0.0% packet loss' $f; result "A  LAN: Mac 1 -> Mac 2 ping, 0% loss" $?
}

B() {
  { stamp
    run cat /etc/resolver/teamepicrouter.test
    run dig @127.0.0.1 $APP
    run dig @$MAC1 api.teamepicrouter.test
    run dscacheutil -q host -a name $APP
    run dig @127.0.0.1 google.com +short
  } > evidence/B-dns/mac1-resolve.txt
  # Committed copy of the dnsmasq log: startup + our domain only (the raw log, git-ignored, has Mac 2's personal lookups).
  q=evidence/B-dns/dnsmasq-team-queries.txt
  { echo "\$ grep -E 'started|using|teamepicrouter\\.test' evidence/B-dns/dnsmasq-log.txt"
    grep -E 'started|using|teamepicrouter\.test' evidence/B-dns/dnsmasq-log.txt; } > $q
  [ "$(dig +short @127.0.0.1 $APP)" = $MAC1 ] &&
  grep -q "query\[A\] $APP from $MAC2" $q &&
  [ "$(dig +short @$MAC1 api.teamepicrouter.test)" = $MAC1 ] &&
  dscacheutil -q host -a name $APP | grep -q "ip_address: $MAC1" &&
  [ -n "$(dig +short @127.0.0.1 google.com)" ]
  result "B  DNS: $APP -> $MAC1 via dnsmasq (dig + system resolver), Mac 2's queries logged, google.com forwarded" $?
}

C() {
  { stamp; run $CURL -si http://$MAC2:3001/api/status; } > evidence/C-backends/curl-a-from-mac1.txt
  { stamp; run $CURL -si http://$MAC2:3002/api/status; } > evidence/C-backends/curl-b-from-mac1.txt
  grep -q 'X-Backend: A' evidence/C-backends/curl-a-from-mac1.txt &&
  grep -q 'X-Backend: B' evidence/C-backends/curl-b-from-mac1.txt
  result "C  Backends: Mac 2 :3001 -> A, :3002 -> B (reached over the LAN)" $?
}

D() {
  f=evidence/D-loadbalancing/alternation-https-from-mac1.txt
  { stamp
    echo "\$ for i in 1 2 3 4 5 6; do $CURL -s -D - -o /dev/null https://$APP/api/status | grep -i x-backend; done"
    for i in 1 2 3 4 5 6; do $CURL -s -D - -o /dev/null https://$APP/api/status | grep -i x-backend; done
  } > $f
  seq=$(grep -io 'x-backend: [AB]' $f | awk '{print $2}' | tr -d '\n')
  [ "$seq" = ABABAB ] || [ "$seq" = BABABA ]; result "D  Round-robin by name over HTTPS: $seq" $?
}

E() {
  { stamp
    run openssl x509 -in tls/$APP.crt -noout -text
    run "openssl s_client -connect $MAC1:443 -servername $APP -CAfile tls/$APP.crt -verify_hostname $APP </dev/null 2>/dev/null | grep -E 'subject=|issuer=|Protocol|Cipher|Verify return'"
  } > evidence/E-tls/cert-details.txt
  { stamp; run $CURL -v https://$APP/api/status; } > evidence/E-tls/curl-v-mac1.txt
  { stamp; run $CURL -sS https://$MAC1/api/status; } > evidence/E-tls/ip-url-fails-mac1.txt
  { stamp; run $CURL -sI http://$APP/api/status; } > evidence/E-tls/redirect-80-to-443-mac1.txt
  { stamp; run $CURL --http1.1 -sI https://$APP/; run $CURL -sI https://$APP/; } > evidence/E-tls/http1-vs-http2-mac1.txt
  $CURL -s -o /dev/null https://$APP/api/status &&            # verified, no -k
  ! $CURL -s -o /dev/null https://$MAC1/api/status &&         # IP is not in the certificate
  grep -q '^HTTP/1.1 301' evidence/E-tls/redirect-80-to-443-mac1.txt &&
  grep -q '^HTTP/1.1 200' evidence/E-tls/http1-vs-http2-mac1.txt &&
  grep -q '^HTTP/2 200' evidence/E-tls/http1-vs-http2-mac1.txt
  result "E  TLS: cert verified by name (no -k), IP URL rejected, 80->443, HTTP/1.1 + HTTP/2" $?
}

F() {
  f=evidence/F-caching/mac1-full-and-304.txt
  etag=$($CURL -sI https://$APP/ | awk -F': ' 'tolower($1)=="etag"{print $2}' | tr -d '\r')
  { stamp
    echo "## 1. Full request: 200 + Cache-Control + ETag"
    run $CURL -sI https://$APP/
    echo "## 2. Conditional request (twice, so both backends answer): expect 304, no body"
    run $CURL -sI -H "'If-None-Match: $etag'" https://$APP/
    run $CURL -sI -H "'If-None-Match: $etag'" https://$APP/
  } > $f
  grep -q 'cache-control: public, max-age=60' $f && [ "$(grep -c '^HTTP/2 304' $f)" = 2 ] &&
  grep -q 'x-backend: A' <(sed -n '/## 2/,$p' $f) && grep -q 'x-backend: B' <(sed -n '/## 2/,$p' $f)
  result "F  Caching: 200 with max-age=60 + ETag, then 304 from both A and B" $?
}

G() {
  pcap=evidence/G-wireshark/G-full-request.pcap
  [ -f $pcap ] || { echo "SKIP  G  no $pcap yet (Yashi runs mac2/6-capture.sh)"; return; }
  ok=0
  # One tshark line per required item; HTTP on 3001/3002 decoded explicitly.
  t() { echo "## $1"; echo "\$ tshark -r $pcap -Y '$2' -T fields $3"
        line=$($TSHARK -r $pcap -d tcp.port==3001,http -d tcp.port==3002,http -Y "$2" -T fields -E separator=' | ' $3 | head -1)
        echo "${line:-MISSING}"; echo; [ -n "$line" ] || ok=1; }
  {
    stamp
    t "DNS query Mac 2 -> Mac 1 (UDP 53)" 'dns.flags.response == 0 && dns.qry.name == "'$APP'"' \
      '-e frame.number -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e dns.qry.name'
    t "DNS response containing Mac 1 IP" "dns.flags.response == 1 && dns.a == $MAC1" \
      '-e frame.number -e ip.src -e udp.srcport -e ip.dst -e udp.dstport -e dns.a -e dns.resp.ttl'
    t "TCP SYN (client ephemeral port -> 443)" 'tcp.dstport == 443 && tcp.flags.syn == 1 && tcp.flags.ack == 0' \
      '-e frame.number -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e tcp.seq'
    t "TCP SYN-ACK (443 -> client)" 'tcp.srcport == 443 && tcp.flags.syn == 1 && tcp.flags.ack == 1' \
      '-e frame.number -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e tcp.seq -e tcp.ack'
    t "TCP ACK (completes handshake)" 'tcp.dstport == 443 && tcp.flags.syn == 0 && tcp.flags.ack == 1 && tcp.seq == 1 && tcp.ack == 1 && tcp.len == 0' \
      '-e frame.number -e ip.src -e tcp.srcport -e ip.dst -e tcp.dstport -e tcp.seq -e tcp.ack'
    t "TLS ClientHello with SNI (type 1)" 'tls.handshake.type == 1' \
      '-e frame.number -e tcp.srcport -e tcp.dstport -e tls.handshake.extensions_server_name'
    t "TLS ServerHello (type 2)" 'tls.handshake.type == 2' '-e frame.number -e tcp.srcport -e tcp.dstport -e tls.handshake.version'
    t "TLS Certificate (type 11)" 'tls.handshake.type == 11' '-e frame.number -e tcp.srcport -e tcp.dstport -e x509sat.uTF8String'
    t "TLS ChangeCipherSpec (content type 20)" 'tls.record.content_type == 20' '-e frame.number -e ip.src -e tcp.srcport -e tcp.dstport'
    t "TLS Application Data, encrypted (content type 23)" 'tls.record.content_type == 23' '-e frame.number -e ip.src -e tcp.srcport -e tcp.dstport -e tls.record.length'
    t "nginx -> backend: readable plain HTTP request on 3001/3002" 'http.request && (tcp.dstport == 3001 || tcp.dstport == 3002)' \
      '-e frame.number -e ip.src -e ip.dst -e tcp.dstport -e http.request.method -e http.request.uri -e http.host -e http.x_forwarded_for'
    t "backend -> nginx: readable plain HTTP response" 'http.response && (tcp.srcport == 3001 || tcp.srcport == 3002)' \
      '-e frame.number -e ip.src -e tcp.srcport -e ip.dst -e http.response.code -e http.response.line'
  } > evidence/G-wireshark/verification.txt
  result "G  Capture has DNS, TCP handshake, TLS hello/cert/CCS/app-data, plain HTTP to backend" $ok
}

for task in ${@:-A B C D E F G}; do $task; done
