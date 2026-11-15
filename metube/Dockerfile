ARG BUILD_FROM=ghcr.io/alexta69/metube:2026.11.14
FROM ${BUILD_FROM}

# jq reads the Home Assistant options file in run.sh.
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod 0755 /run.sh

ENTRYPOINT ["/run.sh"]
