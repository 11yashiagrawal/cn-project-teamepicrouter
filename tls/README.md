# TLS certificate (self-signed, made with OpenSSL)

Only the **public** certificate `app.teamepicrouter.test.crt` is in git.
The private key lives only on Mac 1 at `/opt/homebrew/etc/nginx/tls/app.teamepicrouter.test.key`
(`*.key` is in `.gitignore`). Never commit or AirDrop it.

## Exact commands (Mac 1, run from this `tls/` folder)

```bash
mkdir -p /opt/homebrew/etc/nginx/tls
# Key goes straight into nginx's folder, so it never touches the repo.
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -config openssl.cnf \
  -keyout /opt/homebrew/etc/nginx/tls/app.teamepicrouter.test.key -out app.teamepicrouter.test.crt
chmod 600 /opt/homebrew/etc/nginx/tls/app.teamepicrouter.test.key
cp app.teamepicrouter.test.crt /opt/homebrew/etc/nginx/tls/
nginx -t && nginx -s reload
```

What `openssl.cnf` puts in the certificate:
- `CN` and `subjectAltName` = `app.teamepicrouter.test`, `api.teamepicrouter.test`. Clients check the **SAN** against
  the name they typed. That's why `https://10.7.5.47` fails: the IP is not in the SAN.
- `CA:FALSE`, `serverAuth`: it's a server certificate, not a CA that could sign others.
- valid 365 days (macOS refuses user-trusted server certs valid > 825 days).

## Trusting it (each client Mac, needs sudo)

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain tls/app.teamepicrouter.test.crt
security verify-cert -c tls/app.teamepicrouter.test.crt -p ssl -s app.teamepicrouter.test
```

Use Apple's `/usr/bin/curl`: it reads the Keychain. Anaconda/Homebrew curl use their own CA file;
for those, `--cacert tls/app.teamepicrouter.test.crt` still verifies properly. **Never** use `-k`.

## Inspect

```bash
openssl x509 -in app.teamepicrouter.test.crt -noout -text
openssl s_client -connect 10.7.5.47:443 -servername app.teamepicrouter.test </dev/null
```
