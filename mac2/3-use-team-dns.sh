#!/bin/bash
# Task B on Mac 2: make Mac 1's dnsmasq this Mac's ONLY DNS server, then test it.
# Asks for your Mac password (sudo). Undo after the project with mac2/undo-dns.sh.
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }

{ echo "# Mac 2 - $(date '+%Y-%m-%d %H:%M:%S')"; echo
  run sudo networksetup -setdnsservers Wi-Fi $MAC1
  run networksetup -getdnsservers Wi-Fi
  run "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
  run "scutil --dns | grep nameserver | head -2"
  run dig app.teamepicrouter.test
  run nslookup app.teamepicrouter.test
  run dig google.com +short
} | tee evidence/B-dns/mac2-dig-nslookup.txt
