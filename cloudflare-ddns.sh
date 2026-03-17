#!/bin/sh
set -e

# Validate required environment variables
for var in CF_API_TOKEN CF_ZONE_ID CF_RECORD_NAME; do
  eval val=\$$var
  if [ -z "$val" ]; then
    echo "ERROR: $var is not set"
    exit 1
  fi
done

CF_RECORD_TYPE="${CF_RECORD_TYPE:-A}"
CF_PROXIED="${CF_PROXIED:-false}"
CF_TTL="${CF_TTL:-1}"

API_BASE="https://api.cloudflare.com/client/v4"

# Get current public IP
echo "Fetching current public IP..."
CURRENT_IP=$(curl -sf https://api.ipify.org) || {
  echo "ERROR: Failed to fetch public IP"
  exit 1
}
echo "Current IP: $CURRENT_IP"

# Get existing DNS record
echo "Fetching DNS record for $CF_RECORD_NAME..."
RECORD_RESPONSE=$(curl -sf \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$API_BASE/zones/$CF_ZONE_ID/dns_records?type=$CF_RECORD_TYPE&name=$CF_RECORD_NAME") || {
  echo "ERROR: Failed to fetch DNS records from Cloudflare"
  exit 1
}

RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id // empty')
RECORD_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content // empty')

if [ -z "$RECORD_ID" ]; then
  # Create new record
  echo "No existing record found. Creating $CF_RECORD_TYPE record for $CF_RECORD_NAME -> $CURRENT_IP"
  CREATE_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"$CF_RECORD_TYPE\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":$CF_TTL,\"proxied\":$CF_PROXIED}" \
    "$API_BASE/zones/$CF_ZONE_ID/dns_records") || {
    echo "ERROR: Failed to create DNS record"
    exit 1
  }

  SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
  if [ "$SUCCESS" = "true" ]; then
    echo "DNS record created successfully."
  else
    echo "ERROR: Failed to create DNS record"
    echo "$CREATE_RESPONSE" | jq '.errors'
    exit 1
  fi
elif [ "$RECORD_IP" = "$CURRENT_IP" ]; then
  echo "DNS record is already up to date ($CURRENT_IP). No changes needed."
else
  # Update existing record
  echo "Updating $CF_RECORD_NAME: $RECORD_IP -> $CURRENT_IP"
  UPDATE_RESPONSE=$(curl -sf -X PUT \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"$CF_RECORD_TYPE\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":$CF_TTL,\"proxied\":$CF_PROXIED}" \
    "$API_BASE/zones/$CF_ZONE_ID/dns_records/$RECORD_ID") || {
    echo "ERROR: Failed to update DNS record"
    exit 1
  }

  SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
  if [ "$SUCCESS" = "true" ]; then
    echo "DNS record updated successfully."
  else
    echo "ERROR: Failed to update DNS record"
    echo "$UPDATE_RESPONSE" | jq '.errors'
    exit 1
  fi
fi
