# Cloudflare DDNS via GitHub Actions

Automatically updates a Cloudflare DNS record with the runner's public IP using a scheduled GitHub Actions workflow inside a Docker container.

## GitHub Secrets (Required)

Go to **Settings → Secrets and variables → Actions** in your repository and add:

| Secret | Description |
|---|---|
| `CF_API_TOKEN` | Cloudflare API token with `Zone.DNS` edit permissions |
| `CF_ZONE_ID` | Zone ID (found on the domain's Overview page in Cloudflare) |
| `CF_RECORD_NAME` | Full DNS record name, e.g. `home.example.com` |

## GitHub Secrets (Optional)

| Secret | Default | Description |
|---|---|---|
| `CF_RECORD_TYPE` | `A` | DNS record type (`A` or `AAAA`) |
| `CF_PROXIED` | `false` | Whether to proxy through Cloudflare (`true`/`false`) |
| `CF_TTL` | `1` | TTL in seconds (`1` = automatic) |

## How It Works

1. The workflow runs on a schedule (every 15 minutes) or via manual dispatch.
2. It builds a lightweight Alpine Docker image with `curl` and `jq`.
3. The container fetches the runner's public IP and compares it to the existing DNS record.
4. If the IP has changed (or no record exists), it creates/updates the record via the Cloudflare API.

## Creating a Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Under **Zone Resources**, select the specific zone you want to update
5. Click **Continue to summary → Create Token**
6. Copy the token and store it as the `CF_API_TOKEN` secret

## Manual Trigger

You can trigger the workflow manually from the **Actions** tab → **Cloudflare DDNS Update** → **Run workflow**.
