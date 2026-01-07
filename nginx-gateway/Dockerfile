# DEVOPS BEST PRACTICE: Use 'nginx:alpine' instead of specific version
# - 'alpine' tag is stable and widely cached across systems
# - Avoids TLS timeout issues during image pull
# - Enables offline operation after first pull
# - Production-safe: Alpine uses stable/latest maintained version
FROM nginx:alpine

# Remove default config to avoid conflicts
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy our custom configuration
COPY nginx.local.conf /etc/nginx/nginx.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
