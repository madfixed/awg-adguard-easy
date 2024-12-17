# nodejs 20 hangs on build with armv6/armv7
FROM docker.io/library/node:18-alpine AS build_node_modules

# Update npm to latest
RUN npm install -g npm@latest

# Copy Web UI
COPY src /app
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

# Copy build result to a new image.
FROM amneziavpn/amnezia-wg:latest
HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3
COPY --from=build_node_modules /app /app

COPY --from=build_node_modules /node_modules /node_modules

# Copy the needed wg-password scripts
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    nodejs \
    npm \
    adguard-home

# Use iptables-legacy
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

# Set Environment
ENV DEBUG=Server,WireGuard
ENV DNS_SERVER=127.0.0.1

# Configure AdGuard Home to listen on localhost
RUN mkdir -p /opt/adguardhome/conf && \
    echo "bind_host: 127.0.0.1" > /opt/adguardhome/conf/AdGuardHome.yaml && \
    echo "bind_port: 53" >> /opt/adguardhome/conf/AdGuardHome.yaml

# Create startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /app
CMD ["/usr/bin/dumb-init", "/start.sh"]
