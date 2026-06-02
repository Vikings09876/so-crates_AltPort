FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    suricata \
    suricata-update \
    tcpdump \
    tshark \
    yara \
    curl \
    unzip \
    file \
    libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# Install Zircolite (pinned version) for Sigma log analysis in an isolated venv
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3-venv \
    python3-dev \
    build-essential \
    rustc \
    cargo \
    libxml2-dev \
    libxslt1-dev \
    && git clone --depth 1 --branch v3.7.1 \
    https://github.com/wagga40/Zircolite.git /usr/local/lib/zircolite && \
    rm -rf /usr/local/lib/zircolite/.git && \
    python3 -m venv /usr/local/lib/zircolite-venv && \
    /usr/local/lib/zircolite-venv/bin/pip install --no-cache-dir \
    -r /usr/local/lib/zircolite/requirements.txt && \
    ln -s /usr/local/lib/zircolite-venv/bin/python3 /usr/local/bin/zircolite-venv-python && \
    rm -rf /var/lib/apt/lists/*

ENV DATA_DIR=/data
ENV BIND_ADDRESS=0.0.0.0
ENV PORT=8000
ENV PYTHONUNBUFFERED=1

WORKDIR /app
COPY config.py db.py models.py validators.py suricata_analyzer.py yara_analyzer.py sigma_analyzer.py file_analyzer.py exif_analyzer.py socrates.py socrates.html ./
COPY static/ static/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Bake Suricata rules into image for air-gapped deployments
RUN mkdir -p /usr/share/suricata/rules && \
    suricata-update --no-test --data-dir /usr/share/suricata --output /usr/share/suricata/rules

# Bake YARA Forge rules into image for air-gapped deployments
RUN mkdir -p /usr/share/yara-rules && \
    curl -fsSL -o /tmp/yara-forge-full.zip \
    "https://github.com/YARAHQ/yara-forge/releases/latest/download/yara-forge-rules-full.zip" && \
    unzip -p /tmp/yara-forge-full.zip "packages/full/yara-rules-full.yar" \
    > /usr/share/yara-rules/yara-rules-full.yar && \
    rm /tmp/yara-forge-full.zip

# Bake Sigma rules (Zircolite JSON format) into image for air-gapped deployments
RUN mkdir -p /usr/share/sigma-rules && \
    curl -fsSL -o /usr/share/sigma-rules/rules_windows_merged.json \
    "https://raw.githubusercontent.com/wagga40/Zircolite-Rules-v2/main/rules_windows_merged.json" && \
    curl -fsSL -o /usr/share/sigma-rules/rules_linux.json \
    "https://raw.githubusercontent.com/wagga40/Zircolite-Rules-v2/main/rules_linux.json"

RUN mkdir -p /data && chown -R 1000:1000 /data && \
    chown -R 1000:1000 /usr/local/lib/zircolite-venv

USER 1000:1000

VOLUME ["/data"]
EXPOSE 8000

ENTRYPOINT ["docker-entrypoint.sh"]
