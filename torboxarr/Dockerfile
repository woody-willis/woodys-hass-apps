ARG BUILD_FROM=mrjoiny/torboxarr:1.0.5
FROM ${BUILD_FROM}

RUN apk add --no-cache jq

COPY run.sh /run.sh
RUN chmod 0755 /run.sh

ENTRYPOINT ["/run.sh"]
