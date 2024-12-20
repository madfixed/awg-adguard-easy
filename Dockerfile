# Use AdGuard Home base image
FROM adguard/adguardhome:latest AS adguard

# Use Node.js 18 alpine image for building node modules
FROM docker.io/library/node:18-alpine AS build_node_modules

# Update npm to the latest version
RUN npm install -g npm@latest

# Copy the source code of the Web UI into the image
COPY src /app
WORKDIR /app

# Install the necessary node modules without dev dependencies
RUN npm ci --omit=dev && mv node_modules /node_modules

# Use the latest Amnezia VPN image as the base image for the final build
FROM amneziavpn/amnezia-wg:latest

# Define a healthcheck to ensure the WireGuard interface is up
HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/wg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3

# Copy the application and node modules from the build stage
COPY --from=build_node_modules /app /app
COPY --from=build_node_modules /node_modules /node_modules

# Copy the WireGuard password script and make it executable
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Install necessary Linux packages excluding AdGuard Home
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    nodejs \
    npm

# Copy AdGuard Home from the adguard stage
COPY --from=adguard /opt/adguardhome /opt/adguardhome

# Use iptables-legacy to avoid compatibility issues
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

# Set environment variables
ENV DEBUG=Server,WireGuard
ENV DNS_SERVER=127.0.0.1

# Configure AdGuard Home to listen on localhost
RUN mkdir -p /opt/adguardhome/conf && \
    echo "bind_host: 127.0.0.1" > /opt/adguardhome/conf/AdGuardHome.yaml && \
    echo "bind_port: 53" >> /opt/adguardhome/conf/AdGuardHome.yaml

# Create the startup script and make it executable
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set the working directory and define the command to run on container start
WORKDIR /app
CMD ["/usr/bin/dumb-init", "/start.sh"]
