#!/bin/bash

HUB="gcr.io/diemvu-sandbox"
REBUILD=true
PILOT_TAG=''
NAMESPACE='istio-system'
ISTIO_PATH='/usr/local/google/home/diemvu/go/src/istio.io/istio'

while getopts st:h:n:i: option
do
  case "${option}"
  in
  s) REBUILD=false;;
  t) REBUILD=false
     PILOT_TAG="${OPTARG}";;
  h) HUB="${OPTARG}";;
  n) NAMESPACE="${OPTARG}";;
  i) ISTIO_PATH="${OPTARG}";;
  esac
done

if [ $REBUILD == true ]; then
  bin/push-docker -hub ${HUB}
fi

if [[ -z $PILOT_TAG ]]; then
  echo "Getting the most recent build from ${HUB}/pilot ..."
  PILOT_TAG=$(gcloud container images list-tags ${HUB}/pilot --format='get(tags)' | head -n 1)
fi

echo "Deploying pilot ${HUB}/pilot:$PILOT_TAG ..."

cat "${ISTIO_PATH}/install/kubernetes/templates/istio-pilot.yaml.tmpl" | sed "s#{ISTIO_NAMESPACE}#${NAMESPACE}#g" | sed "s#{PILOT_HUB}#${HUB}#g" | sed "s#{PILOT_TAG}#${PILOT_TAG}#g" | kubectl apply -f -
