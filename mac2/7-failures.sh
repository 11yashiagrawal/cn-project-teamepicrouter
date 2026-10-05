#!/bin/bash
# Section 6.3 failure demos, Mac 2 side. Each one is restored before the next.
# It pauses whenever Mac 1 or you must do something by hand.
#   mac2/7-failures.sh       all five
#   mac2/7-failures.sh 3     start at failure 3 (3, 4, 5 need nothing from Mac 1)
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
APP=app.teamepicrouter.test
CURL=/usr/bin/curl
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }
pause() { echo; read -r -p ">>> $1  [press Enter when done] "; echo; }
flush() { sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; }
six() { echo "\$ 6 x $CURL -s -D - -o /dev/null https://$APP/api/status"
        for i in 1 2 3 4 5 6; do
          $CURL -s -D - -o /dev/null https://$APP/api/status | grep -iE '^HTTP|x-backend' | tr -d '\r' | paste -sd' ' -
        done; echo; }

f1() {
  echo "########## 1. Wrong DNS server on the client (Mac 2 -> 1.1.1.1)"
  sudo networksetup -setdnsservers Wi-Fi 1.1.1.1; flush
  { echo "# Failure 1 - Mac 2 - $(date '+%F %T')"; echo
    run networksetup -getdnsservers Wi-Fi
    run dig $APP
    run $CURL -sS https://$APP/api/status
    run ping -c 3 $MAC1
  } | tee evidence/failures/1-wrong-dns-server.txt
  sudo networksetup -setdnsservers Wi-Fi $MAC1; flush
  echo "restored: DNS -> $MAC1, $APP -> $(dig +short $APP)"
}

f2() {
  echo "########## 2. DNS record points to the wrong IP"
  pause "Mac 1: start dnsmasq with the WRONG IP (docs/demo-runbook.md, failure 2)"
  flush
  { echo "# Failure 2 - Mac 2 - $(date '+%F %T')"; echo
    run dig +short $APP
    run $CURL -sS https://$APP/api/status
  } | tee evidence/failures/2-dns-wrong-ip.txt
  pause "Mac 1: restart dnsmasq with the NORMAL config"
  flush; echo "restored: $APP -> $(dig +short $APP)"
}

f3() {
  echo "########## 3. One backend stopped"
  pause "Mac 2: press Ctrl+C in the Backend A WINDOW (port 3001), not this one"
  { echo "# Failure 3 - Mac 2 - $(date '+%F %T')"; echo; six; } | tee evidence/failures/3-backend-a-stopped.txt
  pause "Mac 2: restart Backend A in its window:  python3 backend/server.py A 3001"
  echo "waiting 10 s for nginx's fail_timeout..."; sleep 10; six
}

f4() {
  echo "########## 4. Both backends stopped"
  pause "Mac 2: press Ctrl+C in BOTH backend WINDOWS, not this one"
  { echo "# Failure 4 - Mac 2 - $(date '+%F %T')"; echo; run $CURL -v https://$APP/api/status; } \
    | tee evidence/failures/4-both-backends-stopped.txt
  pause "Mac 2: restart BOTH backends in their windows (A 3001 and B 3002)"
  echo "waiting 10 s for nginx's fail_timeout..."; sleep 10; six
}

f5() {
  echo "########## 5. Wrong destination port"
  { echo "# Failure 5 - Mac 2 - $(date '+%F %T')"; echo
    run $CURL -sS https://$APP:8443/
    run nc -vz -G 3 $MAC1 8443
    run nc -vz -G 3 $MAC1 443
    run ping -c 3 $MAC1
  } | tee evidence/failures/5-wrong-port.txt
}

sudo -v || exit 1
for n in $(seq ${1:-1} 5); do f$n; done
echo "Done and restored. Send evidence/failures/ back to Mac 1."
