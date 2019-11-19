#!/bin/bash

export KUBE_API_SERVER=""
export CLUSTER="default"
export CA="$PWD/ca.pem"
export CA_KEY="$PWD/ca-key.pem"
export CA_CONFIG="$PWD/ca-config.json"
export CA_CSR="$PWD/csr.json"
export CSR_GROUP="cicd:execution-operator"
export CSR_USER="cicd:execution"
export CLIENT_NAME="execution"
export CLIENT_USER="execution"
export KUBE_CONTEXT="default"
temp=$(mktemp -u) && export KUBECONFIG="${temp#*\.}.kubeconfig"

log(){
    local LEVEL="$1" && shift
    echo "$LEVEL - $*" >&2
}

usage(){
  log USE "generate --api-server <api-server> [--cluster <cluster>] \
  [--ca <path of ca.pem>] [--ca-key <path of ca-key.pem>] [--user <csr_user>] [--group <csr_group>]"
}

while ARG="$1" && shift; do
  case "$ARG" in
  --api-server)
    KUBE_API_SERVER="$1" && shift
    ;;
  --cluster)
    CLUSTER="$1" && shift
    ;;
  --ca)
    CA="$1" && shift
    ;;
  --ca-key)
    CA_KEY="$1" && shift
    ;;
  --user)
    CSR_USER="$1" && shift
    ;;
  --group)
    CSR_GROUP="$1" && shift
    ;;
  --help)
    usage && exit 0
    ;;
  *)
    shift
    ;;
  esac
done

[ ! -z "$KUBE_API_SERVER" ] || {
  log ERR "apiserver can not be empty" && usage && exit 1
}

if ! which cfssl > /dev/null 2>&1; then
  log ERR "cfssl required" && exit 1
fi

if ! which cfssljson > /dev/null 2>&1; then
  log ERR "cfssljson required" && exit 1
fi

[ -f "$CA" ] && [ -f "$CA_KEY" ] || {
  echo "ca.pem and ca-key.pem required" && usage && exit 1
}

[ ! -f "$KUBECONFIG" ] || {
  log ERR "kubeconfig \"$KUBECONFIG\" is already exist" && exit 1
}

log INFO "api server: $KUBE_API_SERVER"
log INFO "cluster: $CLUSTER"
log INFO "ca: $CA"
log INFO "ca-key: $CA_KEY"
log INFO "csr-user: $CSR_USER"
log INFO "csr-group: $CSR_GROUP"

generate_cert(){
  CONFIG='{
    "signing": {
      "default": {
        "expiry": "87600h"
      },
      "profiles": {
        "kubernetes": {
          "usages": [
              "signing",
              "key encipherment",
              "server auth",
              "client auth"
          ],
          "expiry": "87600h"
        }
      }
    }
  }'
  CSR="{
    \"CN\": \"$CSR_USER\",
    \"key\": {
      \"algo\": \"rsa\",
      \"size\": 2048
    },
    \"names\": [
      {
        \"C\": \"CN\",
        \"L\": \"HangZhou\",
        \"ST\": \"HangZhou\",
        \"O\": \"$CSR_GROUP\",
        \"OU\": \"SkiffExecution\"
      }
    ]
  }"

  cat > "$CA_CONFIG" <<<"$CONFIG" && cat > "$CA_CSR" <<<"$CSR" && \
  [ -f "$CA_CONFIG" ] && [ $CA_CSR ] || {
    log ERR "write ca config or ca csr failed" && return 1
  }

  cfssl gencert --ca "$CA" \
                --ca-key "$CA_KEY" \
                --config "$CA_CONFIG" \
                --profile kubernetes "$CA_CSR" | \
                cfssljson --bare "$CLIENT_NAME"

  [ -f "$CLIENT_NAME.csr" ] && [ -f "$CLIENT_NAME.pem" ] && [ -f "$CLIENT_NAME-key.pem" ] || {
    log ERR "cfssl gencert failed" && return 1
  }

  rm -f "$CA_CONFIG" "$CA_CSR" || return 1
}

generate_kubeconfig(){
  kubectl config set-cluster "$CLUSTER" --server="$KUBE_API_SERVER" \
    --certificate-authority="$CA" \
    --embed-certs=true \
    --kubeconfig="$KUBECONFIG" && \

  kubectl config set-credentials "$CLIENT_USER" \
      --certificate-authority="$CA" \
      --embed-certs=true \
      --client-key="$CLIENT_NAME-key.pem" \
      --client-certificate="$CLIENT_NAME.pem" \
      --kubeconfig="$KUBECONFIG" && \

  kubectl config set-context "$KUBE_CONTEXT" --cluster="$CLUSTER" \
      --user="$CLIENT_USER" \
      --kubeconfig="$KUBECONFIG" && \

  kubectl config use-context "$KUBE_CONTEXT" --kubeconfig="$KUBECONFIG"

  [ -f "$KUBECONFIG" ] || {
    log ERR "$KUBECONFIG is not generated" && exit 1
  }

  rm -f "$CLIENT_NAME.pem" "$CLIENT_NAME-key.pem" "$CLIENT_NAME.csr" || return 1
}

show(){
  echo "======KUBECONFIG======"
  cat "$KUBECONFIG"
  echo "======base64 encode KUBECONFIG======"
  base64 "$KUBECONFIG"
}

generate_cert && generate_kubeconfig && show && {
  rm -f "$KUBECONFIG"
} || {
  log ERR "failed" && exit 1
}
