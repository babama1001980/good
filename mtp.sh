#!/bin/bash

red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
export SECRET=${SECRET:-$(echo -n "$USERNAME+$HOSTNAME" | md5sum | head -c 32)}
WORKDIR="${HOME}/mtp" && mkdir -p "$WORKDIR"
pgrep -x mtp > /dev/null && pkill -9 mtp >/dev/null 2>&1

check_port() {
  purple "正在安装中,请稍等..."
  # 指定固定端口
  MTP_PORT=25898
  port_list=$(devil port list)
  tcp_ports=$(echo "$port_list" | grep -c "tcp")

  # 检查指定端口是否已被占用
  if echo "$port_list" | grep -q "tcp.*$MTP_PORT"; then
    green "端口 $MTP_PORT 已存在，直接使用"
  else
    if [[ $tcp_ports -ge 1 ]]; then
      # 如果已有其他 TCP 端口，删除一个以腾出空间（根据需要调整逻辑）
      old_tcp_port=$(echo "$port_list" | awk '/tcp/ {print $1}' | head -n 1)
      devil port del tcp $old_tcp_port
      green "已删除旧 TCP 端口: $old_tcp_port"
    fi

    # 添加指定的端口
    result=$(devil port add tcp $MTP_PORT 2>&1)
    if [[ $result == *"succesfully"* ]]; then
      green "已成功添加 TCP 端口: $MTP_PORT"
    else
      red "无法添加端口 $MTP_PORT，可能已被占用或无权限"
      exit 1
    fi
  fi

  devil binexec on >/dev/null 2>&1
  green "使用 $MTP_PORT 作为 TG 代理端口"
}

get_ip() {
  IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
  API_URL="https://status.eooce.com/api"
  IP1=""; IP2=""; IP3=""
  AVAILABLE_IPS=()

  for ip in "${IP_LIST[@]}"; do
    RESPONSE=$(curl -s --max-time 2 "${API_URL}/${ip}")
    if [[ -n "$RESPONSE" ]] && [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
      AVAILABLE_IPS+=("$ip")
    fi
  done

  [[ ${#AVAILABLE_IPS[@]} -ge 1 ]] && IP1=${AVAILABLE_IPS[0]}
  [[ ${#AVAILABLE_IPS[@]} -ge 2 ]] && IP2=${AVAILABLE_IPS[1]}
  [[ ${#AVAILABLE_IPS[@]} -ge 3 ]] && IP3=${AVAILABLE_IPS[2]}

  if [[ -z "$IP1" ]]; then
    red "所有 IP 都被墙，请更换服务器安装"
    exit 1
  fi
}

download_run() {
  if [ -e "${WORKDIR}/mtg" ]; then
    cd ${WORKDIR} && chmod +x mtg
    nohup ./mtg run -b 0.0.0.0:$MTP_PORT $SECRET --stats-bind=127.0.0.1:$MTP_PORT >/dev/null 2>&1 &
  else
    mtg_url="https://github.com/babama1001980/good/releases/download/npc/mtg"
    wget -q -O "${WORKDIR}/mtg" "$mtg_url"

    if [ -e "${WORKDIR}/mtg" ]; then
      cd ${WORKDIR} && chmod +x mtg
      nohup ./mtg run -b 0.0.0.0:$MTP_PORT $SECRET --stats-bind=127.0.0.1:$MTP_PORT >/dev/null 2>&1 &
    fi        
  fi
}

generate_info() {
  purple "\n分享链接:\n"
  LINKS=""
  [[ -n "$IP1" ]] && LINKS+="tg://proxy?server=$IP1&port=$MTP_PORT&secret=$SECRET"
  [[ -n "$IP2" ]] && LINKS+="\n\ntg://proxy?server=$IP2&port=$MTP_PORT&secret=$SECRET"
  [[ -n "$IP3" ]] && LINKS+="\n\ntg://proxy?server=$IP3&port=$MTP_PORT&secret=$SECRET"

  green "$LINKS\n"
  echo -e "$LINKS" > link.txt

  cat > ${WORKDIR}/restart.sh <<EOF
#!/bin/bash

pkill mtg
cd ~ && cd ${WORKDIR}
nohup ./mtg run -b 0.0.0.0:$MTP_PORT $SECRET --stats-bind=127.0.0.1:$MTP_PORT >/dev/null 2>&1 &
EOF
}

check_port
get_ip
download_run
generate_info
