#!/bin/bash
# Task E on Mac 2 (Yashi): trust our self-signed certificate (PUBLIC cert only, no key).
# Asks for your Mac password (sudo).
cd "$(dirname "$0")/.." || exit 1
run() { echo "\$ $*"; eval "$*" 2>&1; echo; }

{ echo "# Mac 2 (Yashi) - $(date '+%Y-%m-%d %H:%M:%S')"; echo
  run sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain tls/app.teamepicrouter.test.crt
  run security verify-cert -c tls/app.teamepicrouter.test.crt -p ssl -s app.teamepicrouter.test
} | tee evidence/E-tls/mac2-trust-cert.txt
