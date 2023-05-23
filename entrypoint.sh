#!/usr/bin/env bash
# 其他Paas保活
PAAS1=https://lapis-future-sprout.glitch.me/
PAAS2=
PAAS3=

# koyeb账号保活
KOYEB_ACCOUNT=
KOYEB_PASSWORD=

# 哪吒三个参数，不需要的话可以留空，删除或在这三行最前面加 # 以注释
NEZHA_SERVER=
NEZHA_PORT=
NEZHA_KEY=

# Argo 固定域名隧道的两个参数,这个可以填 Json 内容或 Token 内容，获取方式看 https://github.com/fscarmen2/X-for-Glitch，不需要的话可以留空，删除或在这三行最前面加 # 以注释
ARGO_AUTH='{"AccountTag":"a56b07a2e3456e1bb60ee6afcd4dc745","TunnelSecret":"fT8tuRYJGCR2pof+HqP3M1vbNeBAK2dRLzSektHr0II=","TunnelID":"c7adce3d-aeac-47b0-8fbf-5f42ca414d92"}'
ARGO_DOMAIN=goorm.ifyuhid.ml

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    [[ "\$ARGO_AUTH" =~ TunnelSecret ]] && echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json && echo -e "tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")\ncredentials-file: /app/tunnel.json" > tunnel.yml && ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml --url http://localhost:8080 run 2>&1 &
    [[ \$ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]] && ./cloudflared tunnel --edge-ip-version auto run --token ${ARGO_AUTH} 2>&1 &
    ./cloudflared access tcp --hostname grpc2.ifyuhid.ml --listener localhost:55556 >/dev/null 2>&1 &
  else
    ./cloudflared tunnel --edge-ip-version auto --no-autoupdate --logfile argo.log --loglevel info --url http://localhost:8080 2>&1 &
    sleep 5
    ARGO_DOMAIN=\$(cat argo.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}

check_file
run
ABC
}

# Paas保活
generate_keeplive() {
  cat > paaslive.sh << EOF
#!/usr/bin/env bash

# 传参
PAAS1=${PAAS1}
PAAS2=${PAAS2}
PAAS3=${PAAS3}

# 判断变量并保活
if [ -n "\${PAAS1}" ] && [ -n "\${PAAS2}" ] && [ -n "\${PAAS3}" ]; then
  while true; do
    curl \${PAAS1}
    curl \${PAAS2}
    curl \${PAAS3}
    rm -rf /dev/null
    sleep 240
  done
elif [ -n "\${PAAS1}" ] && [ -n "\${PAAS2}" ]; then
  while true; do
    curl \${PAAS1}
    curl \${PAAS2}
    rm -rf /dev/null
    sleep 240
  done
elif [ -n "\${PAAS1}" ]; then
  while true; do
    curl \${PAAS1}
    rm -rf /dev/null
    sleep 240
  done
else
  exit 1
fi
EOF
}

# koyeb保活
generate_koyeb() {
  cat > koyeb.sh << EOF
#!/usr/bin/env bash

# 传参
KOYEB_ACCOUNT=${KOYEB_ACCOUNT}
KOYEB_PASSWORD=${KOYEB_PASSWORD}

# 两个变量不全则不运行保活
check_variable() {
  [[ -z "\${KOYEB_ACCOUNT}" || -z "\${KOYEB_ACCOUNT}" ]] && exit
}

# 开始保活
run() {
while true
do
  curl -sX POST https://app.koyeb.com/v1/account/login -H 'Content-Type: application/json' -d '{"email":"'"\${KOYEB_ACCOUNT}"'","password":"'"\${KOYEB_PASSWORD}"'"}'
  rm -rf /dev/null
  sleep $((60*60*24*5))
done
}
check_variable
run
EOF
}

# nezha探针
generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf nezha-agent) ]] && echo "哪吒客户端正在运行中!" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY} 2>&1 &
}

check_run
check_variable
download_agent
run
EOF
}

generate_pm2_file() {
    cat > ecosystem.config.js << EOF
module.exports = {
  "apps":[
      {
          "name":"web",
          "script":"/app/hi run"
      }
  ]
}
EOF
}

generate_argo
generate_keeplive
generate_koyeb
generate_nezha
generate_pm2_file
[ -e argo.sh ] && bash argo.sh
[ -e paaslive.sh ] && nohup bash paaslive.sh >/dev/null 2>&1 &
[ -e koyeb.sh ] && nohup bash koyeb.sh >/dev/null 2>&1 &
[ -e nezha.sh ] && bash nezha.sh
[ -e ecosystem.config.js ] && pm2 start
