FROM alpine:3.19

RUN apk add --no-cache curl jq

COPY cloudflare-ddns.sh /usr/local/bin/cloudflare-ddns.sh
RUN chmod +x /usr/local/bin/cloudflare-ddns.sh

ENTRYPOINT ["/usr/local/bin/cloudflare-ddns.sh"]
