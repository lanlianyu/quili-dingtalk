#!/bin/bash

# 从环境变量设置文件读取环境变量
source "$ENV_FILE"

# 检查环境变量是否设置
if [[ -z "$DINGTALK_WEBHOOK_URL" || -z "$DINGTALK_SECRET" || -z "$SERVER_NAME" || -z "$LOOP_INTERVAL" ]]; then
    echo "请确保在 $ENV_FILE 中设置 DINGTALK_WEBHOOK_URL、DINGTALK_SECRET、SERVER_NAME 和 LOOP_INTERVAL。"
    exit 1
fi

# 日志文件路径
LOG_FILE="/root/monitor.log"

# 计算签名
calculate_signature() {
    local timestamp=$(date "+%s%3N")
    local secret="$DINGTALK_SECRET"
    local string_to_sign="${timestamp}\n${secret}"
    local sign=$(echo -ne "${string_to_sign}" | openssl dgst -sha256 -hmac "${secret}" -binary | base64)
    echo "${timestamp}&${sign}"
}

# 发送钉钉消息
send_dingtalk_message() {
    local message=$1
    local sign=$(calculate_signature)
    local url="${DINGTALK_WEBHOOK_URL}&timestamp=$(echo ${sign} | cut -d'&' -f1)&sign=$(echo ${sign} | cut -d'&' -f2)"

    # 添加当前时间到消息内容中
    local current_time=$(TZ="Asia/Shanghai" date "+%Y-%m-%d %H:%M:%S")
    local message_with_time="${current_time} - ${SERVER_NAME} - ${message}"

    echo "发送钉钉消息: ${message_with_time}" >> "$LOG_FILE"

    # 发送请求并检查返回状态
    local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${url}" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"${message_with_time}\"}}")

    if [[ "$response" -ne 200 ]]; then
        echo "钉钉消息发送失败，HTTP 状态码: $response" >> "$LOG_FILE"
    fi
}

# 执行命令并获取输出
execute_and_send() {
    cd ~/ceremonyclient/node || { echo "目录不存在"; exit 1; }
    local output=$(./node-1.4.21.1-linux-amd64 -node-info 2>&1)

    # 添加日期标记
    local current_date=$(TZ="Asia/Shanghai" date "+%Y-%m-%d")
    echo "---- $current_date 查询结果 ----" >> "$LOG_FILE"

    # 发送命令输出到钉钉，并记录日志
    if [[ -n "$output" ]]; then
        send_dingtalk_message "$output"
        echo "$output" >> "$LOG_FILE"
    else
        send_dingtalk_message "命令执行失败或无输出"
        echo "命令执行失败或无输出" >> "$LOG_FILE"
    fi
}

# 主循环
while true; do
    # 执行任务
    execute_and_send

    # 等待设定的时间
    sleep "$LOOP_INTERVAL"
done
