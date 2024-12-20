#!/bin/sh

# Start AdGuard Home
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml &

# Start WireGuard and other necessary services
/usr/bin/wg-quick up wg0

# Start the Node.js application
node /app/wgpw.mjs "$@"

# Keep the container running
tail -f /dev/null
