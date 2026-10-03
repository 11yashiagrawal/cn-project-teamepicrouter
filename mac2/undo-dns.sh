#!/bin/bash
# After the project (Yashi): give Mac 2 its normal, automatic DNS back.
sudo networksetup -setdnsservers Wi-Fi Empty
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
networksetup -getdnsservers Wi-Fi
# Optional, also remove our certificate from the Keychain:
#   sudo security delete-certificate -c app.teamepicrouter.test /Library/Keychains/System.keychain
