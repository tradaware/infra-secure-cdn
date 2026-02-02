FROM alpine:3.20 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    linux-headers \
    pcre2-dev \
    openssl-dev \
    zlib-dev \
    libxml2-dev \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    wget \
    git

# Set nginx and module versions
ENV NGINX_VERSION=1.24.0

# Download nginx source
WORKDIR /tmp
RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -xzf nginx-${NGINX_VERSION}.tar.gz

# Clone the HMAC secure link module
RUN git clone https://github.com/nginx-modules/ngx_http_hmac_secure_link_module.git

# Build nginx with the HMAC secure link module
WORKDIR /tmp/nginx-${NGINX_VERSION}
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-http_realip_module \
    --with-threads \
    --with-stream \
    --with-file-aio \
    --with-http_v2_module \
    --add-module=/tmp/ngx_http_hmac_secure_link_module && \
    make && \
    make install

# --- Runtime stage ---
FROM alpine:3.20

# Install only runtime dependencies
RUN apk add --no-cache \
    pcre2 \
    openssl \
    zlib \
    libxml2 \
    libxslt \
    gd \
    geoip

# Create nginx user
RUN addgroup -S nginx && adduser -S -D -H -G nginx nginx

# Copy nginx from builder
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx

# Create cache directories
RUN mkdir -p /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp \
    /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx

# Create data directory
RUN mkdir -p /mnt/data/private && \
    chown -R nginx:nginx /mnt/data

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
