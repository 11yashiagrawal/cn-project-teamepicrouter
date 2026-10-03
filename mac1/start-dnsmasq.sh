#!/bin/bash
# Start (or restart) dnsmasq on Mac 1 in the background. Needs sudo (port 53).
# Every query, with the client's IP, is logged to evidence/B-dns/dnsmasq-log.txt
#   mac1/start-dnsmasq.sh            normal records (both names -> Mac 1)
#   mac1/start-dnsmasq.sh wrong-ip   failure demo 2 (both names -> Mac 2)
# Watch live:  tail -f evidence/B-dns/dnsmasq-log.txt
cd "$(dirname "$0")/.." || exit 1
LOG=$PWD/evidence/B-dns/dnsmasq-log.txt
CONF=$PWD/dns/dnsmasq.conf
if [ "$1" = wrong-ip ]; then
  sed 's#/10.7.5.47$#/10.7.2.167#' dns/dnsmasq.conf > /tmp/dnsmasq-wrong-ip.conf
  CONF=/tmp/dnsmasq-wrong-ip.conf
fi
[ -e "$LOG" ] || touch "$LOG"   # after the 1st start dnsmasq owns this file (user nobody)
sudo pkill dnsmasq; sleep 1
sudo /opt/homebrew/sbin/dnsmasq -C "$CONF" --log-facility="$LOG" && sleep 1
pgrep -fl dnsmasq && grep address= "$CONF"
