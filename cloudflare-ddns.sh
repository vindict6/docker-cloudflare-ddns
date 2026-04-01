#!/bin/sh
set -e

# Validate required environment variables
for var in CF_API_TOKEN CF_ZONE_ID; do
  eval val=\$$var
  if [ -z "$val" ]; then
    echo "ERROR: $var is not set"
    exit 1
  fi
done

CONFIG_FILE="${CONFIG_FILE:-/config.json}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Configuration file not found at $CONFIG_FILE"
  exit 1
fi

API_BASE="https://api.cloudflare.com/client/v4"

# Update or create a single DNS record
update_record() {
  RECORD_NAME="$1"
  RECORD_TYPE="$2"
  RECORD_PROXIED_SETTING="$3"
  RECORD_TTL="$4"
  RECORD_CONTENT="$5"

  echo ""
  echo "--- Processing $RECORD_NAME (Type: $RECORD_TYPE, Proxied: $RECORD_PROXIED_SETTING) ---"
  echo "Fetching DNS record for $RECORD_NAME..."
  
  # Note: The API returns multiple types if we don't filter, but we filter by type in the URL
  RECORD_RESPONSE=$(curl -sf \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    "$API_BASE/zones/$CF_ZONE_ID/dns_records?type=$RECORD_TYPE&name=$RECORD_NAME") || {
    echo "ERROR: Failed to fetch DNS records from Cloudflare for $RECORD_NAME"
    return 1
  }

  RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id // empty')
  RECORD_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content // empty')
  RECORD_PROXIED=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].proxied // empty')
  RECORD_CURRENT_TTL=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].ttl // empty')

  if [ -z "$RECORD_ID" ]; then
    # Create new record
    echo "No existing record found. Creating $RECORD_TYPE record for $RECORD_NAME -> $RECORD_CONTENT"
    CREATE_RESPONSE=$(curl -sf -X POST \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$RECORD_CONTENT\",\"ttl\":$RECORD_TTL,\"proxied\":$RECORD_PROXIED_SETTING}" \
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
  elif [ "$RECORD_IP" = "$RECORD_CONTENT" ] && [ "$RECORD_PROXIED" = "$RECORD_PROXIED_SETTING" ] && [ "$RECORD_CURRENT_TTL" = "$RECORD_TTL" ]; then
    echo "DNS record for $RECORD_NAME is already up to date ($RECORD_CONTENT, proxied=$RECORD_PROXIED, ttl=$RECORD_TTL). No changes needed."
  else
    # Update existing record
    echo "Updating $RECORD_NAME: content=$RECORD_IP -> $RECORD_CONTENT, proxied=$RECORD_PROXIED -> $RECORD_PROXIED_SETTING, ttl=$RECORD_CURRENT_TTL -> $RECORD_TTL"
    UPDATE_RESPONSE=$(curl -sf -X PUT \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$RECORD_CONTENT\",\"ttl\":$RECORD_TTL,\"proxied\":$RECORD_PROXIED_SETTING}" \
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

# Main loop to persistently update every 15 minutes
while true; do
  # Get current public IP (cache it once per cycle)
  echo "Fetching current public IP..."
  CURRENT_IP=$(curl -sf https://api.ipify.org) || {
    echo "ERROR: Failed to fetch public IP"
    exit 1
  }
  echo "Current IP: $CURRENT_IP"

  FAILED=0

  # Process records from config file
  # We read the JSON array and process each element
  jq -c '.[]' "$CONFIG_FILE" | while read -r record; do
    REC_NAME=$(echo "$record" | jq -r '.name')
    REC_TYPE=$(echo "$record" | jq -r '.type // "A"')
    REC_PROXIED=$(echo "$record" | jq -r '.proxied // false')
    REC_TTL=$(echo "$record" | jq -r '.ttl // 1')
    
    # If content is supplied directly in JSON, use it.
    # Otherwise fallback to the dynamically fetched public IP (typical for A/AAAA records).
    REC_CONTENT=$(echo "$record" | jq -r ".content // \"$CURRENT_IP\"")

    if [ -z "$REC_NAME" ] || [ "$REC_NAME" = "null" ]; then
      echo "ERROR: Record name is missing in config file"
      FAILED=1
      continue
    fi

    update_record "$REC_NAME" "$REC_TYPE" "$REC_PROXIED" "$REC_TTL" "$REC_CONTENT" || FAILED=1
  done

  if [ "$FAILED" -ne 0 ]; then
    echo ""
    echo "WARNING: One or more records failed to update in this cycle."
  fi

  echo "Sleeping for 15 minutes..."
  sleep 900
done


