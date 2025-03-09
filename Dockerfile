FROM ubuntu:noble
#FROM ubuntu:noble-20250127
LABEL maintainer="Lucas Albers <https://github.com/lalbers-lz4>"
LABEL org.opencontainers.image.source="https://hub.docker.com/r/lalberslz4/squid-deb-proxy"

# Set environment variables in a single layer
ENV USE_ACL=1 \
    USE_AVAHI=0 \
    DEBIAN_FRONTEND=noninteractive

# Install packages and clean up in a single layer
# Keep apt lists for better caching
RUN apt-get update && apt-get install -y --no-install-recommends \
    avahi-utils \
    avahi-daemon \
    squid-deb-proxy \
    squid-deb-proxy-client \
    netcat-traditional \
    && apt-get clean && rm -rf /tmp/* /var/tmp/*

# Copy configuration files (COPY instead of ADD)
COPY etc /etc

# Additional config and prepare for non-root execution
RUN echo \
'refresh_pattern rpm$   129600 100% 129600\n\
shutdown_lifetime 1 second\n\
pipeline_prefetch on\n\
icp_port 0\n\
htcp_port 0\n\
icp_access deny all\n\
htcp_access deny all\n\
snmp_port 0\n\
snmp_access deny all\n\
pid_filename none\n\
logfile_rotate 0\n'\
    >> /etc/squid-deb-proxy/squid-deb-proxy.conf \
    && mkdir -p /data \
    && ln -sf /data /var/cache/squid-deb-proxy \
    && ln -sf /dev/stdout /var/log/squid-deb-proxy/access.log \
    && ln -sf /dev/stdout /var/log/squid-deb-proxy/store.log \
    && ln -sf /dev/stdout /var/log/squid-deb-proxy/cache.log \
    && mkdir -p /var/run/squid-deb-proxy \
    && chown -R 10000:10000 /data /var/log/squid-deb-proxy /etc/squid-deb-proxy /var/run/squid-deb-proxy

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Define volume
VOLUME ["/data"]

# Expose ports
EXPOSE 8000 5353/udp

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD nc -z localhost 8000 || exit 1

# Switch to non-root user (using numeric ID for better security)
ENV PATH=/usr/local/squid/sbin:/usr/local/squid/bin:$PATH
USER 10000:10000
EXPOSE 3128

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["squid", "-N"]
