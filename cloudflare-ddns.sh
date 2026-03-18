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
CF_TTL="${CF_TTL:-1}"

# Default to proxied if not explicitly set or empty
if [ -z "$CF_PROXIED" ]; then
  CF_PROXIED="true"
fi

API_BASE="https://api.cloudflare.com/client/v4"

# Get current public IP
echo "Fetching current public IP..."
CURRENT_IP=$(curl -sf https://api.ipify.org) || {
  echo "ERROR: Failed to fetch public IP"
  exit 1
}
echo "Current IP: $CURRENT_IP"

# Check if a record should be proxied
is_proxied() {
  local record=$1
  
  # If CF_PROXIED_RECORDS is set, only proxy records in that list
  if [ -n "$CF_PROXIED_RECORDS" ]; then
    # adding commas to ensuring exact match (e.g. ,www.vinsix.com,)
    if echo ",$CF_PROXIED_RECORDS," | grep -q ",$record,"; then
      echo "true"
    else
      echo "false"
    fi
  else
    # Fallback to the global CF_PROXIED behavior
    echo "$CF_PROXIED"
  fi
}

# Update or create a single DNS record
update_record() {
  RECORD_NAME="$1"
  RECORD_PROXIED_SETTING=$(is_proxied "$RECORD_NAME")

  echo ""
  echo "--- Processing $RECORD_NAME (Proxied: $RECORD_PROXIED_SETTING) ---"
  echo "Fetching DNS record for $RECORD_NAME..."
  RECORD_RESPONSE=$(curl -sf \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_BASE/zones/$CF_ZONE_ID/dns_records?type=$CF_RECORD_TYPE&name=$RECORD_NAME") || {
    echo "ERROR: Failed to fetch DNS records from Cloudflare for $RECORD_NAME"
    return 1
  }

  RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id // empty')
  RECORD_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content // empty')
  RECORD_PROXIED=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].proxied // empty')

  if [ -z "$RECORD_ID" ]; then
    # Create new record
    echo "No existing record found. Creating $CF_RECORD_TYPE record for $RECORD_NAME -> $CURRENT_IP"
    CREATE_RESPONSE=$(curl -sf -X POST \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$CF_RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":$CF_TTL,\"proxied\":$RECORD_PROXIED_SETTING}" \
      "$API_BASE/zones/$CF_ZONE_ID/dns_records") || {
      echo "ERROR: Failed to create DNS record for $RECORD_NAME"
      return 1
    }

    SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
      echo "DNS record created successfully for $RECORD_NAME."
    else
      echo "ERROR: Failed to create DNS record for $RECORD_NAME"
      echo "$CREATE_RESPONSE" | jq '.errors'
      return 1
    fi
  elif [ "$RECORD_IP" = "$CURRENT_IP" ] && [ "$RECORD_PROXIED" = "$RECORD_PROXIED_SETTING" ]; then
    echo "DNS record for $RECORD_NAME is already up to date ($CURRENT_IP, proxied=$RECORD_PROXIED). No changes needed."
  else
    # Update existing record
    echo "Updating $RECORD_NAME: IP=$RECORD_IP -> $CURRENT_IP, proxied=$RECORD_PROXIED -> $RECORD_PROXIED_SETTING"
    UPDATE_RESPONSE=$(curl -sf -X PUT \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$CF_RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":$CF_TTL,\"proxied\":$RECORD_PROXIED_SETTING}" \
      "$API_BASE/zones/$CF_ZONE_ID/dns_records/$RECORD_ID") || {
      echo "ERROR: Failed to update DNS record for $RECORD_NAME"
      return 1
    }

    SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
      echo "DNS record updated successfully for $RECORD_NAME."
    else
      echo "ERROR: Failed to update DNS record for $RECORD_NAME"
      echo "$UPDATE_RESPONSE" | jq '.errors'
      return 1
    fi
  fi
}

# Process each comma-separated record name
FAILED=0
IFS=','
for name in $CF_RECORD_NAME; do
  # Trim whitespace
  name=$(echo "$name" | xargs)
  update_record "$name" || FAILED=1
done

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo "ERROR: One or more records failed to update."
  exit 1
fi
