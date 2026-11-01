# Team parts — Team Epic Router

The platform itself is one Terraform project. For submission and viva, the work is also divided into four parts, one per member and per machine role. Each folder is self-contained: role document, the configuration that person owns, their evidence, and the commands that prove it.

| Part | Member | Enrollment no. | Machine | Node | Responsibility |
|---|---|---|---|---|---|
| [`abhijeet/`](abhijeet/) | Abhijeet | 2401010013 | Mac 1 | node-1 | Terraform infrastructure, automation (`scripts/`, `Makefile`), primary DNS (dnsmasq), test client, repository integration |
| [`yashi/`](yashi/) | Yashi Agrawal | 2401020078 | Mac 2 | node-2 | Edge: nginx reverse proxy, TLS termination, round-robin load balancer, caching headers |
| [`nishant/`](nishant/) | Nishant Ranjan Singh | 2401010301 | Mac 3 | node-3 | Backend A (`:3001`), backup DNS, standby edge, architecture document |
| [`prashant/`](prashant/) | Prashant Pandey | 2401010339 | Mac 4 | node-4 | Backend B (`:3002`), test client, packet capture, evidence and report |

## How the repository is divided

- `infra/`, `scripts/`, `config/`, `node-bin/`, `Makefile`, `settings.env` — the working platform. `config/` holds the canonical templates that `make converge` renders onto every machine.
- `docs/`, `evidence/` — shared documentation and captured output.
- `team/<name>/` — that member's part. It includes a rendered copy of the configuration they own and the evidence that proves their layer works. A rendered copy is a snapshot for review; the canonical template stays in `config/`.

## Workflow

1. Abhijeet pushes the shared platform and `team/abhijeet/` to `main`.
2. Each other member pushes only their own `team/<name>/` folder to `main`, using the `PUSH-PROMPT.md` inside their part. Their commits are dated to the day they did that work.
3. The result is one complete, runnable project plus four clearly attributable parts.

Do not rewrite another member's part. If a shared file must change, change it in the canonical location (`config/`, `scripts/`, `infra/`) and mention it in the commit message.
