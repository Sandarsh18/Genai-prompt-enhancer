FROM nginx:1.27-alpine

# Remove default config to avoid conflicts
RUN rm -f /etc/nginx/conf.d/default.conf

# DEVOPS: Use Docker network configuration for portability
# nginx.docker.conf uses container names instead of localhost/host.docker.internal
COPY nginx.docker.conf /etc/nginx/nginx.conf

# Busybox wget in Alpine is fine for lightweight health checks
EXPOSE 8080

# Health check for container orchestration
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
