# Stage 1 - build optimized React bundle
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev=false
COPY . ./
# Set the gateway URL for the browser to connect to
ARG VITE_GATEWAY_URL=http://localhost:8088
ENV VITE_GATEWAY_URL=${VITE_GATEWAY_URL}
RUN npm run build

# Stage 2 - serve static assets via nginx
FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
