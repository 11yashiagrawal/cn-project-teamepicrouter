#!/bin/bash
# Task A on Mac 2 (Yashi): print this Mac's network identity, then ping Mac 1.
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }
ping -c 1 -t 3 $MAC1 >/dev/null   # wake-up ping (not recorded): Wi-Fi power-save/ARP can drop the first packet

{ echo "# Mac 2 (Yashi) - $(date '+%Y-%m-%d %H:%M:%S')"; echo
  run "networksetup -listallhardwareports | grep -A2 'Wi-Fi'"
  run ipconfig getifaddr en0
  run ipconfig getoption en0 subnet_mask
  run "route -n get default | grep -E 'gateway|interface'"
  run "ifconfig en0 | grep -E 'ether|inet '"
  run ping -c 4 $MAC1
} | tee evidence/A-lan/mac2-ip-and-ping.txt
