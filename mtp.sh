#!/bin/bash

red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
HOSTNAME=$(hostname)
# 如果 whoami 失败，使用 UID 或默认值
USERNAME=$(whoami 2>/dev/null || echo "user$UID" | tr '[:upper:]' '[:lower:]')
export SECRET=${SECRET:-$(echo -n "$USERNAME+$HOSTNAME" | md5sum | head -c 32)}
WORKDIR="${HOME}/mtp" && mkdir -p "$WORKDIR"
pgrep -x mtp > /dev/null && pkill -9 mtp >/dev/null 2>&1

check_port() {
  purple "正在安装中,请稍等..."
  # 直接指定固定端口，不检测是否可用
  MTP_PORT=25898
  green "使用 $MTP_PORT 作为 TG 代理端口"
}

get_ip() {
  # 移除对 devil 的依赖，使用 curl 获取公网 IP
  IP1=$(curl -s http://ifconfig.me || curl -s https://api.ipify.org)
  if [[ -z "$IP1" || ! "$IP1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    red "无法获取服务器公网 IP，请检查网络或更换服务器"
    exit 1
  fi
  green "使用 IP: $IP1"
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
    else
      red "下载 mtg 失败，请检查网络或 URL"
      exit 1
    fi        
  fi
}

generate_info() {
  purple "\n分享链接:\n"
  LINKS="tg://proxy?server=$IP1&port=$MTP_PORT&secret=$SECRET"

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
