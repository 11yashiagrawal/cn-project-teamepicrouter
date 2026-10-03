#!/bin/bash
# Task G on Mac 2 (Yashi): capture ONE full request, DNS -> TCP -> TLS -> HTTP, into a .pcap.
# Asks for your Mac password (sudo). Both backends must be running.
cd "$(dirname "$0")/.." || exit 1
MAC1=10.7.5.47
PCAP=evidence/G-wireshark/G-full-request.pcap

sudo -v || exit 1   # ask for the password once, before the capture starts
# Only traffic to/from Mac 1, so other apps' HTTPS doesn't clutter the capture.
# -U: write each packet immediately, so the file is complete when we stop it.
sudo tcpdump -U -i en0 -w $PCAP "host $MAC1 and (port 53 or port 443 or port 3001 or port 3002)" &
sleep 2
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder   # force a fresh DNS query
sleep 1
# TLS 1.2 on purpose: TLS 1.3 encrypts the Certificate message, so Wireshark couldn't show it.
/usr/bin/curl -v --http1.1 --tls-max 1.2 https://app.teamepicrouter.test/api/status 2>&1 \
  | tee evidence/G-wireshark/curl-v-during-capture.txt
sleep 2
# Signal tcpdump itself: sudo ignores signals sent from its own process group.
sudo pkill -INT -x tcpdump; wait
sudo chown "$USER" $PCAP
ls -l $PCAP
