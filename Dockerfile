FROM alpine:3.19

RUN apk add --no-cache curl jq

COPY config.json /config.json
COPY cloudflare-ddns.sh /usr/local/bin/cloudflare-ddns.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/cloudflare-ddns.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
