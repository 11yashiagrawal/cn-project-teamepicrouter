# Mac 2 kit: Backends A + B, test client, packet capture

Your Mac runs **both backends** (ports 3001 and 3002) and is the **main test client**.
Mac 1 (`10.7.5.47`) runs the DNS server (dnsmasq) and the edge (nginx).

Every script saves its output into `evidence/…` with the command printed above it.
When you finish, send the whole `evidence/` folder back to Mac 1.

> Scripts that say **sudo** will ask for *your Mac's login password*. Typing shows nothing; that's normal.

## 0. Setup (once)

1. Get the project folder onto your Mac (GitHub clone or the AirDrop zip from Mac 1).
2. Open **Terminal** and go into the folder, for example:
   ```bash
   cd ~/Downloads/cn-project-teamepicrouter
   ```
3. Make the scripts runnable:
   ```bash
   chmod +x mac2/*.sh
   ```
4. Be on the **same Wi-Fi** as Mac 1. Keep your Mac awake and plugged in during the session.

## 1. LAN check (Task A)

```bash
mac2/1-ip-and-ping.sh
```
**You should see:** your IP (`10.7.x.x`), mask `255.255.224.0`, gateway `10.7.0.1`, and `0.0% packet loss` to Mac 1.
**If not:** check that both Macs are on the same Wi-Fi network, then tell Mac 1. If it says *No route to host*,
go to System Settings → Privacy & Security → Local Network and turn **Terminal** on.

## 2. Start the two backends (Task C)

Open **two new Terminal windows** (⌘N), `cd` into the project folder in each, then:

| Window | Command |
|---|---|
| Backend A | `python3 backend/server.py A 3001` |
| Backend B | `python3 backend/server.py B 3002` |

**You should see:** `Backend A listening on 0.0.0.0:3001` (and the B line).
If macOS asks *"Do you want python3 to accept incoming network connections?"*, click **Allow**.
If it asks to install *Command Line Tools* for python3, click **Install** and wait.
**Leave both windows open** for the whole session. Every request shows up there as
`[A] from 10.7.5.47 (real client 10.7.2.167) …`. **Take a screenshot of these log lines** (proof that requests come via nginx on Mac 1).

Now tell Mac 1 "backends up" so it can check them.

## 3. Use the team DNS server (Task B), sudo

Do this only after Mac 1 says dnsmasq is running.
```bash
mac2/3-use-team-dns.sh
```
**You should see:** `nameserver[0] : 10.7.5.47`, and in the `dig` output `ANSWER SECTION … 10.7.5.47` and `SERVER: 10.7.5.47#53`.
**If dig times out:** Mac 1's dnsmasq isn't running, or its firewall blocks it.
**Note:** your Mac now uses Mac 1 for *all* DNS. If Mac 1 is off, websites won't load. Run `mac2/undo-dns.sh` to go back.

## 4. Trust our certificate (Task E), sudo

```bash
mac2/4-trust-cert.sh
```
**You should see:** `...certificate verification successful.`

## 5. Tests: load balancing, TLS, HTTP/2, caching (Tasks D, E, F)

```bash
mac2/5-tests.sh
```
**You should see:**
- `x-backend: A`, `B`, `A`, `B`, `A`, `B`
- in `curl -v`: the server certificate for `app.teamepicrouter.test` accepted, then `HTTP/2 200` (no error)
- the IP URL fails with an SSL/certificate error (**correct**: the certificate is for the name, not the IP)
- `HTTP/1.1 301` to `https://…` for port 80
- `HTTP/1.1 200` vs `HTTP/2 200`
- `HTTP/2 200` with `cache-control: public, max-age=60` and `etag`, then `HTTP/2 304` twice (once from A, once from B)

**Browser screenshots (manual):** open **Safari** → `https://app.teamepicrouter.test`, click the padlock → screenshot.
Then Chrome → DevTools (⌥⌘I) → Network tab → reload twice → screenshot the `200` then `304` rows with response headers.

## 6. Packet capture (Task G), sudo

```bash
mac2/6-capture.sh
```
**You should see:** curl output ending in `{"backend": "…", "status": "ok"}`, then the `.pcap` file listed with a size > 0.

## 7. Failure demos (Section 6.3)

Do this together with Mac 1: it pauses whenever one of you must do something.
```bash
mac2/7-failures.sh
```
To redo from a given demo, add its number, e.g. `mac2/7-failures.sh 3` (3, 4, 5 need nothing from Mac 1).
When it says *Ctrl+C*, press it in the **backend windows**, not in the window running this script.

## 8. Send the evidence back

Send the whole `evidence/` folder to Mac 1 (AirDrop, or commit it if you have the GitHub repo).

## After the project

```bash
mac2/undo-dns.sh
```
This sets your DNS back to automatic.
