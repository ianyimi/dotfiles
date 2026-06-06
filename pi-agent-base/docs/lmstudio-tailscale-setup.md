# LM Studio via Tailscale — Pi Local Models Setup

Connect pi to LM Studio running on another Mac on your Tailnet.

---

## Prerequisites

- LM Studio installed and running on the remote Mac
- Tailscale running on both machines (MagicDNS enabled)
- Bitwarden CLI unlocked (`bw unlock`)

---

## Step 1 — Get Your Tailscale Hostname

On the **remote Mac** (the one running LM Studio), run:

```bash
tailscale status
```

Find the MagicDNS hostname for that machine — it looks like:

```
my-mac.tail12345.ts.net
```

Or use the Tailscale IP (`100.x.x.x`) if MagicDNS isn't enabled.

---

## Step 2 — Enable LM Studio's Local Server

On the **remote Mac**, in LM Studio:

1. Open the **Local Server** tab (the `<->` icon in the left sidebar)
2. Click **Start Server** — it runs on port `1234` by default
3. Load a model — note the exact model ID shown (you'll need it in Step 5)

---

## Step 3 — Add the Bitwarden Item

In your Bitwarden vault, create a new **Login** item:

| Field    | Value                                                   |
| -------- | ------------------------------------------------------- |
| Name     | `LM Studio Tailscale URL`                               |
| Username | `lmstudio`                                              |
| Password | Your Tailscale hostname, e.g. `my-mac.tail12345.ts.net` |

> Save **just the hostname** — no `http://`, no port number.

---

## Step 4 — Apply the Chezmoi Config

The `dot_pi/agent/models.json.tmpl` and the updated `run_after_sync-pi-agent-base.sh.tmpl`
are already committed to your chezmoi source. Run your apply alias:

```bash
cma
```

This will:

- Render `models.json.tmpl` → `~/.pi/agent/models.json` with the Bitwarden hostname injected
- Rsync `pi-agent-base/` → `~/.pi/agent/` without touching `models.json`

---

## Step 5 — Add Your Model IDs

Open the template in chezmoi:

```bash
cme pi-agent-base  # or navigate manually
```

File: `~/.local/share/chezmoi/dot_pi/agent/models.json.tmpl`

Replace `MODEL_ID_HERE` with the exact model ID from LM Studio's Local Server tab:

```json
"models": [
  { "id": "lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF" }
]
```

Add more models as needed:

```json
"models": [
  { "id": "lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF" },
  { "id": "bartowski/Qwen2.5-Coder-7B-Instruct-GGUF" }
]
```

Run `cma` again to re-render.

---

## Step 6 — Verify in Pi

In a pi session, open the model picker:

```
/model
```

Your local models should appear listed under the `lmstudio` provider. Select one and run a quick test.

---

## Troubleshooting

**Models don't appear in `/model`**

- Confirm LM Studio's server is started and a model is loaded
- Ping the remote Mac over Tailscale: `ping my-mac.tail12345.ts.net`
- Check `~/.pi/agent/models.json` exists and has the correct hostname rendered (no template syntax remaining)

**Connection refused**

- LM Studio server only starts when you explicitly click **Start Server** — it doesn't auto-start
- Default port is `1234` — confirm it hasn't been changed in LM Studio settings

**Bitwarden not resolving**

- Make sure your BW session is active: `bw unlock --check`
- Re-run `cma` with a fresh session: `bwsr && cma`

**`models.json` gets deleted on `cma`**

- The rsync exclude for `models.json` is set in `run_after_sync-pi-agent-base.sh.tmpl`
- Confirm that file has `--exclude='models.json'` in the rsync flags

---

## Reference

- LM Studio default API base: `http://<host>:1234/v1`
- Pi models config docs: `~/.local/share/fnm/.../pi-coding-agent/docs/models.md`
- Chezmoi template syntax: `{{ (bitwarden "item" "ITEM_NAME").login.password }}`
