FROM fabiocicerchia/nginx-lua:latest

RUN apk add --no-cache --virtual .build-deps gcc musl-dev luajit-dev \
    && luarocks --lua-version=5.1 install lua-cjson LUA_INCDIR=/usr/include/luajit-2.1 \
    && apk del .build-deps \
    && luajit -e 'require("cjson")'
