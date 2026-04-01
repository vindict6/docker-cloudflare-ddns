# Cloudflare DDNS Docker Container

A lightweight Docker container that persistently runs in the background, updating Cloudflare DNS records with your current public IP every 15 minutes. It uses a `config.json` file to allow flexible configuration of multiple records (A, CNAME, etc.) simultaneously.

## Features

- Runs persistently (no external cron or action runner required)
- Checks and updates IP every 15 minutes
- Supports multiple records with mixed types (`A`, `CNAME`, `AAAA`, etc.) and proxy settings
- Lightweight Alpine base image

## Prerequisites

- Docker installed
- A Cloudflare account and Domain
- Cloudflare API Token (with `Zone.DNS` edit permissions)
- Cloudflare Zone ID (found on the domain's Overview page)

## Configuration (`config.json`)

Create a `config.json` file to define the DNS records you want to manage.

```json
[
  {
    "name": "example.com",
    "type": "A",
    "proxied": true,
    "ttl": 1
  },
  {
    "name": "sub.example.com",
    "type": "A",
    "proxied": false,
    "ttl": 120
  },
  {
    "name": "cname.example.com",
    "type": "CNAME",
    "content": "example.com",
    "proxied": true,
    "ttl": 1
  }
]
```

### Record properties:
- `name` (Required): The DNS record name (e.g. `example.com` or `sub.example.com`).
- `type` (Optional): The record type. Defaults to `"A"`.
- `proxied` (Optional): Whether the record is proxied through Cloudflare. Defaults to `false`.
- `ttl` (Optional): Time to live. `1` equals "Automatic". Defaults to `1`.
- `content` (Optional): The target content of the record. If omitted, the script automatically fetches and uses your current public IP (ideal for `A` records).

## Usage

Run the container, passing in your Cloudflare credentials as environment variables and mounting your `config.json`:

```bash
docker build -t cloudflare-ddns .

docker run -d \
  --name cloudflare-ddns \
  -e CF_API_TOKEN="your_cloudflare_api_token_here" \
  -e CF_ZONE_ID="your_cloudflare_zone_id_here" \
  -v $(pwd)/config.json:/config.json \
  cloudflare-ddns
```

### Environment Variables

| Variable | Description |
|---|---|
| `CF_API_TOKEN` | **Required.** Your Cloudflare API token. |
| `CF_ZONE_ID` | **Required.** The Zone ID for your domain. |
| `CONFIG_FILE` | *Optional.* Path to the config file inside the container (defaults to `/config.json`). |

## Creating a Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Under **Zone Resources**, select the specific zone you want to update
5. Click **Continue to summary → Create Token**
6. Copy the token and use it for `CF_API_TOKEN`
