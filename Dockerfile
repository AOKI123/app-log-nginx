#!/bin/bash -ilex
FROM openresty/openresty:alpine-fat

# https://github.com/openresty/docker-openresty/
# http://totogoo.com/article/143/nginx-lua-nsq.html
# https://github.com/Meituan-Dianping/Logan

ARG LUA_KAFKA_VERSION="0.06"

LABEL lua_kafka_version="${LUA_KAFKA_VERSION}"

RUN echo $PATH \
    && whoami

RUN mkdir -p /opt/openresty/lua/ \
    && apk add --no-cache git mercurial \
    && apk add --no-cache zlib-dev \
    && luarocks install lua-zlib

WORKDIR /opt/openresty

RUN curl -fSL https://github.com/doujiang24/lua-resty-kafka/archive/v${LUA_KAFKA_VERSION}.tar.gz -o lua-resty-kafka-${LUA_KAFKA_VERSION}.tar.gz \
    && tar xzf lua-resty-kafka-${LUA_KAFKA_VERSION}.tar.gz \
    && rm -f lua-resty-kafka-${LUA_KAFKA_VERSION}.tar.gz \
    && mv lua-resty-kafka-${LUA_KAFKA_VERSION}/lib/resty/kafka /usr/local/openresty/lualib/resty/ \
    && rm -fr lua-resty-kafka-${LUA_KAFKA_VERSION} \
    && curl -fSL https://github.com/rainingmaster/lua-resty-nsq/archive/master.zip -o lua-resty-nsq-master.zip \
    && unzip lua-resty-nsq-master.zip \
    && rm -f lua-resty-nsq-master.zip \
    && mv lua-resty-nsq-master/lib/resty/nsq /usr/local/openresty/lualib/resty/ \
    && rm -fr lua-resty-nsq-master \
    && rm -f /usr/local/openresty/nginx/html/*

COPY nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/
COPY nginx/conf/default.conf /etc/nginx/conf.d/
COPY nginx/lua /opt/openresty/lua/
COPY nginx/aes_fix/aes_pad.lua /usr/local/openresty/lualib/resty/
ADD nginx/www /usr/local/openresty/nginx/html/

COPY nginx/docker-entrypoint.sh /opt/openresty/

ENV DOMAIN="log-test.percentcompany.com"
ENV AES_KEY="1234567890123456"
ENV AES_IV="1234567890123456"
ENV KAFKA_BROKERS="{{host=\"172.17.0.4\",port=9092}}"
ENV KAFKA_TOPIC="app-log"
ENV KAFKA_PRODUCER_CONF="{ producer_type = \"sync\" }"



EXPOSE 80
ENTRYPOINT ["./docker-entrypoint.sh"]