# Cloudflare DDNS via GitHub Actions

Automatically updates a Cloudflare DNS record with the runner's public IP using a scheduled GitHub Actions workflow inside a Docker container.

## GitHub Secrets (Required)

Go to **Settings → Secrets and variables → Actions** in your repository and add:

| Secret | Description |
|---|---|
| `CF_API_TOKEN` | Cloudflare API token with `Zone.DNS` edit permissions |
| `CF_ZONE_ID` | Zone ID (found on the domain's Overview page in Cloudflare) |
| `CF_RECORD_NAME` | Comma-separated DNS record names, e.g. `example.com,www.example.com` |

## GitHub Secrets (Optional)

| Secret | Default | Description |
|---|---|---|
| `CF_RECORD_TYPE` | `A` | DNS record type (`A` or `AAAA`) |
| `CF_PROXIED` | `true` | Whether to proxy through Cloudflare (`true`/`false`). Default fallback if `CF_PROXIED_RECORDS` is empty. |
| `CF_PROXIED_RECORDS` | `empty` | Explicitly define which records should be proxied (comma-separated). e.g., `vinsix.com,www.vinsix.com`. If used, any record NOT in this list will be DNS-only (`false`). |
| `CF_TTL` | `1` | TTL in seconds (`1` = automatic) |

## How It Works

1. The workflow runs on a schedule (every 15 minutes) or via manual dispatch.
2. It builds a lightweight Alpine Docker image with `curl` and `jq`.
3. The container fetches the runner's public IP and compares it to each existing DNS record.
4. If the IP has changed (or no record exists), it creates/updates each record via the Cloudflare API.

> **Tip:** To update both the root domain and `www`, set `CF_RECORD_NAME` to `example.com,www.example.com`.

## Creating a Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Under **Zone Resources**, select the specific zone you want to update
5. Click **Continue to summary → Create Token**
6. Copy the token and store it as the `CF_API_TOKEN` secret

## Manual Trigger

You can trigger the workflow manually from the **Actions** tab → **Cloudflare DDNS Update** → **Run workflow**.
