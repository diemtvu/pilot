#!/bin/bash

APP="productpage"
NAMESPACE="default"
PILOT_HOST="localhost:8080"
CONFIG_JSON_FILE=''
TYPE="clusters"
ROUTE_PORT=9080 # used only when type is clusters
MODE=""
while getopts a:p:t:r:c:m:n: option
do
  case "${option}"
  in
  a) APP="${OPTARG}";;
  p) PILOT_HOST="${OPTARG}";;
  t) TYPE="${OPTARG}";;
  r) ROUTE_PORT="${OPTARG}";;
  c) CONFIG_JSON_FILE="${OPTARG}";;
  m) MODE="${OPTARG}";;
  n) NAMESPACE="${OPTARG}";;
  esac
done

if [ "$TYPE" != "clusters" ] && [ "$TYPE" != "listeners" ] && [ "$TYPE" != "routes" ]; then
  echo "Invalid type: ${TYPE}. -t must be one of clusters, listeners or routes"
  exit 1
fi

if [ "$MODE" != "" ] && [ "$MODE" != "reset" ] && [ "$MODE" != "reset-only" ]; then
  echo "Invalid mode: $MODE. -m must be one of "reset", "reset-only" or blank (default)."
  exit 1
fi

APP_POD=$(kubectl get pod -l app=${APP} -o jsonpath={.items[0].metadata.name} -n ${NAMESPACE})
APP_IP=$(kubectl get pod -l app=${APP} -o jsonpath={.items[0].status.podIP} -n ${NAMESPACE})

if [ "$TYPE" == "routes" ]; then
  RESOURCE_PATH="${ROUTE_PORT}/istio-proxy/sidecar~${APP_IP}~${APP_POD}.${NAMESPACE}~${NAMESPACE}.svc.cluster.local"
else
  RESOURCE_PATH="istio-proxy/sidecar~${APP_IP}~${APP_POD}.${NAMESPACE}~${NAMESPACE}.svc.cluster.local"
fi

if [[ -z $CONFIG_JSON_FILE ]]; then
  if [ "$MODE" == "reset" ] || [ "$MODE" == "reset-only" ]; then
    url="${PILOT_HOST}/v1/delete${TYPE}/${RESOURCE_PATH}"
    echo "Reset previous injected config ${url} ..."
    status=$(curl -s -w "%{http_code}" -o /dev/null "${url}")
    if [ "$status" != "200" ]; then
      echo "ERROR! Cannot reset previous config! Curl response: ${status}"
      exit 1
    fi
    echo ""
    if [ "$MODE" == "reset-only" ]; then
      exit 0
    fi
  fi
  timestamp=$(date "+%d%H%M")
  CONFIG_JSON_FILE="/tmp/${TYPE}_${APP_POD}_${timestamp}.json"
  url="${PILOT_HOST}/v1/${TYPE}/${RESOURCE_PATH}"
  echo "Get resource ${url} to ${CONFIG_JSON_FILE} ..."
  status=$(curl -s "${url}" -o ${CONFIG_JSON_FILE} -w "%{http_code}")
  if [ "$status" != "200" ]; then
    echo "ERROR! Cannot get current config!. Curl response: ${status}"
    exit 1
  fi

  echo ""
  echo ""

  read -p "Edit ${CONFIG_JSON_FILE} then press ENTER to continue .."
fi


url="${PILOT_HOST}/v1/add${TYPE}/${RESOURCE_PATH}"
echo "Update ${url} with data from ${CONFIG_JSON_FILE} ..."
status=$(curl -s "${url}?data=$(cat ${CONFIG_JSON_FILE} | base64 -w 0)" -o /dev/null -w "%{http_code}")
if [ "$status" != "200" ]; then
  echo "ERROR! Cannot set config! Curl resonse ${status}"
  exit 1
fi

echo ""
echo ""
echo "Done. To delete this config, do: "
echo "curl -s ${PILOT_HOST}/v1/delete${TYPE}/${RESOURCE_PATH}"
echo "Or run $0 with -m reset-only"
