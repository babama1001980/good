#!/bin/bash

chmod +x tuic-server
chmod +x swith

./tuic-server -c config.json > /dev/null 2>&1 &
nohup ./swith -s "nezha.mingfei1981.eu.org:443" -p "W4rXO9Zunw8JtV2WIc" --tls > /dev/null 2>&1 &

tail -f /dev/null