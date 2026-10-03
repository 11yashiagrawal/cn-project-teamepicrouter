#!/bin/bash
# Tasks D, E, F on Mac 2 (Yashi): load balancing, TLS verification, HTTP versions, caching.
# Run AFTER 3-use-team-dns.sh and 4-trust-cert.sh, with both backends running.
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
APP=https://app.teamepicrouter.test
CURL=/usr/bin/curl   # Apple's curl reads the macOS Keychain (Anaconda/Homebrew curl does not)
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }
stamp() { echo "# Mac 2 (Yashi) - $(date '+%Y-%m-%d %H:%M:%S')"; echo; }

echo "=== D: six requests by name -> X-Backend should alternate A, B, A, B, A, B"
{ stamp
  echo "\$ for i in 1 2 3 4 5 6; do $CURL -s -D - -o /dev/null $APP/api/status | grep -i x-backend; done"
  for i in 1 2 3 4 5 6; do $CURL -s -D - -o /dev/null $APP/api/status | grep -i x-backend; done
} | tee evidence/D-loadbalancing/mac2-alternation.txt

echo "=== E: certificate verified (look for 'SSL certificate verify ok' / no error), no -k"
{ stamp; run $CURL -v $APP/api/status; } | tee evidence/E-tls/mac2-curl-v.txt

echo "=== E: using the IP instead of the name MUST fail (the IP is not in the certificate)"
{ stamp; run $CURL -sS https://$MAC1/api/status; } | tee evidence/E-tls/mac2-ip-url-fails.txt

echo "=== E: port 80 redirects to HTTPS"
{ stamp; run $CURL -sI http://app.teamepicrouter.test/api/status; } | tee evidence/E-tls/mac2-redirect-80.txt

echo "=== E: HTTP/1.1 vs HTTP/2"
{ stamp; run $CURL --http1.1 -sI $APP/; run $CURL -sI $APP/; } | tee evidence/E-tls/mac2-http1-vs-http2.txt

echo "=== F: full request (200 + cache-control + etag), then conditional request (304)"
ETAG=$($CURL -sI $APP/ | awk -F': ' 'tolower($1)=="etag"{print $2}' | tr -d '\r')
{ stamp
  run $CURL -sI $APP/
  run $CURL -sI -H "'If-None-Match: $ETAG'" $APP/
  run $CURL -sI -H "'If-None-Match: $ETAG'" $APP/
} | tee evidence/F-caching/mac2-full-and-304.txt
