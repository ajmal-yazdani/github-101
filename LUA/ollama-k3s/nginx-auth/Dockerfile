FROM openresty/openresty:focal
RUN luarocks install lua-cjson
RUN mkdir -p /etc/nginx/lua
COPY lua/api-key-auth.lua /etc/nginx/lua/
RUN chmod -R 755 /etc/nginx/lua
RUN mkdir -p /etc/nginx/conf.d
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
RUN mkdir -p /var/log/nginx/ && touch /var/log/nginx/error.log && touch /var/log/nginx/access.log
EXPOSE 80 443
CMD ["openresty", "-g", "daemon off;"]
