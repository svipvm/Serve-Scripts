FROM debian:12

LABEL maintainer="Headscale Docker Deployment"
LABEL description="Headscale - An open source implementation of the Tailscale control server"

ARG TARGETPLATFORM

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY package/headscale_0.26.1_linux_amd64.deb /tmp/packages/
COPY package/headscale_0.26.1_linux_arm64.deb /tmp/packages/

RUN case "$TARGETPLATFORM" in \
        "linux/amd64") \
            cp /tmp/packages/headscale_0.26.1_linux_amd64.deb /tmp/headscale.deb ;; \
        "linux/arm64") \
            cp /tmp/packages/headscale_0.26.1_linux_arm64.deb /tmp/headscale.deb ;; \
        "") \
            case "$(uname -m)" in \
                x86_64) \
                    cp /tmp/packages/headscale_0.26.1_linux_amd64.deb /tmp/headscale.deb ;; \
                aarch64) \
                    cp /tmp/packages/headscale_0.26.1_linux_arm64.deb /tmp/headscale.deb ;; \
                *) \
                    echo "Error: Unsupported architecture $(uname -m). Only x86_64 and aarch64 are supported." && \
                    exit 1 ;; \
            esac ;; \
        *) \
            echo "Error: Unsupported platform $TARGETPLATFORM. Only linux/amd64 and linux/arm64 are supported." && \
            exit 1 ;; \
    esac

RUN dpkg -i /tmp/headscale.deb \
    && rm /tmp/headscale.deb

RUN mkdir -p /var/run/headscale \
    && chown -R headscale:headscale /var/lib/headscale \
    && chown -R headscale:headscale /var/run/headscale \
    && chmod 770 /var/run/headscale

USER headscale

EXPOSE 8080 9090 50443

VOLUME ["/var/lib/headscale", "/var/run/headscale"]

ENTRYPOINT ["/usr/bin/headscale"]
CMD ["serve", "--config", "/etc/headscale/config.yaml"]
