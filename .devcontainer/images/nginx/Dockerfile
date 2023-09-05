FROM alpine

RUN apk --no-cache add build-base pcre-dev openssl-dev gzip curl jq zlib-dev \
    && NGINX_VERSION=$(curl -s https://nginx.org/en/download.html | grep -o -E -m 1 "nginx-[0-9]+\.[0-9]+\.[0-9]+" | cut -d'-' -f2 | head -n 1) \
    && UPLOAD_VERSION=$(curl -s https://api.github.com/repos/fdintino/nginx-upload-module/tags | jq -r '.[0].name') \
    && wget -P /tmp https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar -zxvf /tmp/nginx-${NGINX_VERSION}.tar.gz -C /tmp \
    && wget -P /tmp https://github.com/fdintino/nginx-upload-module/archive/${UPLOAD_VERSION}.tar.gz && tar -zxvf /tmp/${UPLOAD_VERSION}.tar.gz -C /tmp \
    && cd /tmp/nginx-${NGINX_VERSION}\
    && ./configure \
    --add-module=/tmp/nginx-upload-module-${UPLOAD_VERSION}\
    --with-http_stub_status_module \
    && make \
    && make install\
    && rm -rf /usr/local/nginx/conf

COPY conf /usr/local/nginx/conf

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]