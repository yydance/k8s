#!/bin/bash
# make bootstrap_token


BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom |od -An -t x |tr -d ' ')
token_dir="/data/app/k8s/etc"

cat >${token_dir}/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
