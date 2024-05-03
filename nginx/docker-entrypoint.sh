#!/bin/sh

envsubst < /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf
envsubst < /opt/openresty/lua/test.lua > /opt/openresty/lua/test.lua
envsubst < /opt/openresty/lua/kafka-test.lua > /opt/openresty/lua/kafka-test.lua
envsubst < /opt/openresty/lua/percent-content-parser.lua > /opt/openresty/lua/percent-content-parser.lua
envsubst < /opt/openresty/lua/logan-content-parser.lua > /opt/openresty/lua/logan-content-parser.lua

cat /etc/nginx/conf.d/default.conf

echo "start run openresty"

exec /usr/local/openresty/bin/openresty -g "daemon off;"
