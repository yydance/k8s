#!/bin/bash

# 配置 Kafka 命令路径和引导服务器地址
KAFKA_BIN="/data/apps/kafka/bin"
BOOTSTRAP_SERVER="172.16.250.26:9092"
ZK_SERVER="172.16.250.26:2181,172.16.250.27:2181,172.16.250.28:2181"
BROKER_LIST="2,4,8"
all_topics="all-topics.json"
reassign_topics="reassign_topics.json"

function generate_all_topics() {
# 获取所有 Topic 列表
TOPICS_LIST=$(${KAFKA_BIN}/kafka-topics.sh \
  --bootstrap-server ${BOOTSTRAP_SERVER} \
  --list)

# 检查是否获取到 Topic 列表
if [ -z "${TOPICS_LIST}" ]; then
  echo "❌ 未获取到任何 Topic 列表，请检查 Kafka 集群连接和权限。"
  exit 1
fi


# 将 Topic 列表转换为 JSON 格式
echo "✅ 开始生成 $$all_topics 文件"
echo "{" > $all_topics
echo "  \"topics\": [" >> $all_topics

IFS=$'\n'
first=true
for topic in ${TOPICS_LIST}; do
  if [ "$first" = true ]; then
    first=false
    printf "    {\"topic\": \"%s\"}" "$topic" >> $all_topics
  else
    printf ",\n    {\"topic\": \"%s\"}" "$topic" >> $all_topics
  fi
done

echo "" >>$all_topics
echo "  ]," >> $all_topics
echo "  \"version\": 1" >> $all_topics
echo "}" >> $all_topics

echo "✅ 已成功生成 all-topics.json 文件，包含所有 Kafka Topic。"
}

function generate_reassign_topics() {
${KAFKA_BIN}/kafka-reassign-partitions.sh \
  --bootstrap-server ${BOOTSTRAP_SERVER} \
  --zookeeper ${ZK_SERVER} \
  --topics-to-move-json-file $all_topics \
  --broker-list ${BROKER_LIST} --generate |grep -A1 'Proposed'|grep -v Proposed >reassign_topics.json
}

function exec_reassign_topics() {
${KAFKA_BIN}/kafka-reassign-partitions.sh \
  --bootstrap-server ${BOOTSTRAP_SERVER} \
  --zookeeper ${ZK_SERVER} \
  --reassignment-json-file $reassign_topics --execute --throttle 300000000
}

#generate_all_topics
#generate_reassign_topics
exec_reassign_topics
