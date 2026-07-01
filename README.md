# ll

## Fix Codex Desktop session stream disconnects


Because your web ChatGPT session works but the desktop app does not, run the one-command repair:

```bash
./scripts/repair-codex-desktop.sh
```

The repair command resets Desktop-only app state, repairs local session files, and launches Codex Desktop with a clean network environment. If you prefer to run the steps manually:

```bash
./scripts/reset-codex-desktop-app-state.sh
./scripts/fix-codex-desktop-session.sh
./scripts/launch-codex-desktop-clean-network.sh
```

The reset script quits Codex Desktop and moves app-local Codex state, caches, saved state, and preferences into a timestamped backup under `~/.codex-desktop-backups/`, so the reset is reversible.

To preview what will be moved without changing anything:

```bash
./scripts/reset-codex-desktop-app-state.sh --dry-run
```

The error below means Codex Desktop cannot keep its request open to the ChatGPT Codex backend:

```text
stream disconnected before completion: error sending request for url (https://chatgpt.com/backend-api/codex/response)
```

In practice this is most often caused by a broken proxy, VPN, firewall, TLS inspection, or captive-portal network path. Start Codex Desktop with OpenAI/ChatGPT endpoints bypassing proxy variables:

```bash
./scripts/launch-codex-desktop-clean-network.sh
```

That launcher removes `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` for the Codex Desktop process and sets `NO_PROXY` / `no_proxy` for ChatGPT and OpenAI hosts.

If Codex Desktop still cannot start, also repair local Codex session state:

```bash
./scripts/fix-codex-desktop-session.sh
```

For deterministic local-only repair without the network preflight, run:

```bash
CODEX_SKIP_NETWORK_CHECK=1 ./scripts/fix-codex-desktop-session.sh
```

After the reset and clean-network launch complete, sign in again if prompted and start a new session.
