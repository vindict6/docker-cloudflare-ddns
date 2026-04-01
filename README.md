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
- `type` (Optional): The DNS record type. Defaults to `"A"`. See [supported record types](#supported-record-types) below.
- `proxied` (Optional): Whether the record is proxied through Cloudflare. Defaults to `false`.
- `ttl` (Optional): Time to live in seconds. `1` equals "Automatic". Defaults to `1`.
- `content` (Optional): The target content of the record. If omitted, the script automatically fetches and uses your current public IP (ideal for `A`/`AAAA` records). **Required** for record types like `CNAME`, `MX`, `TXT`, `SRV`, etc.

### Supported record types

| Type | Content format | Example `content` | Notes |
|---|---|---|---|
| `A` | IPv4 address | `192.0.2.1` | Auto-populated with public IP if `content` is omitted |
| `AAAA` | IPv6 address | `2001:db8::1` | Auto-populated with public IP if `content` is omitted |
| `CNAME` | Hostname | `example.com` | Must point to another domain name |
| `MX` | Mail server hostname | `mail.example.com` | Use `priority` field in Cloudflare API if needed |
| `TXT` | Arbitrary text | `v=spf1 include:_spf.google.com ~all` | Commonly used for SPF, DKIM, domain verification |
| `NS` | Nameserver hostname | `ns1.example.com` | Delegates a subdomain to another nameserver |
| `SRV` | Service record | `0 5 5060 sipserver.example.com` | Format: `priority weight port target` |
| `LOC` | Location | `51 30 12.748 N 0 7 39.612 W 0 0 0 0` | Geographic location of a host |
| `SPF` | SPF record | `v=spf1 include:example.com ~all` | Deprecated in favor of `TXT` |
| `CERT` | Certificate | *(binary/base64)* | Stores certificates and related revocation lists |
| `DNSKEY` | DNS key | *(binary/base64)* | Used for DNSSEC |
| `DS` | Delegation signer | `60485 5 1 2BB183AF...` | DNSSEC delegation |
| `NAPTR` | Naming authority pointer | `100 10 "u" "sip+E2U" "!^.*$!sip:info@example.com!" .` | Used for ENUM and SIP |
| `SMIMEA` | S/MIME cert association | `3 1 1 abcdef...` | Associates S/MIME certificates with domains |
| `SSHFP` | SSH fingerprint | `1 1 abcdef123456...` | Publishes SSH public key fingerprints |
| `TLSA` | TLS authentication | `3 1 1 abcdef...` | DANE — associates TLS certificates with domains |
| `URI` | URI record | `10 1 "https://example.com"` | Maps a hostname to a URI |
| `CAA` | Certification authority auth | `0 issue "letsencrypt.org"` | Controls which CAs can issue certificates for the domain |
| `PTR` | Pointer | `example.com` | Reverse DNS lookup (typically managed by IP provider) |
| `HTTPS` | HTTPS service binding | `1 . alpn="h2"` | Service binding for HTTPS connections |
| `SVCB` | Service binding | `1 . alpn="h2"` | General-purpose service binding |

## Usage

Edit `config.json` with your DNS records, then build and run:

```bash
docker build -t cloudflare-ddns .

docker run -d \
  --name cloudflare-ddns \
  --restart unless-stopped \
  -e CF_API_TOKEN="your_cloudflare_api_token_here" \
  -e CF_ZONE_ID="your_cloudflare_zone_id_here" \
  cloudflare-ddns
```

The `config.json` is baked into the image at build time. To change records, update `config.json` and rebuild the image.

### Environment Variables

| Variable | Description |
|---|---|
| `CF_API_TOKEN` | **Required.** Your Cloudflare API token. |
| `CF_ZONE_ID` | **Required.** The Zone ID for your domain. |

## Creating a Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Under **Zone Resources**, select the specific zone you want to update
5. Click **Continue to summary → Create Token**
6. Copy the token and use it for `CF_API_TOKEN`
