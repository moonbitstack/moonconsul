#!/usr/bin/env bash
# The agents the integration tests connect to: one in dev mode on 8500, and one on 18500 with ACLs
# on, since a dev agent answers the ACL endpoints with "ACL support disabled". Both serve Connect,
# which dev mode turns on by default and the ACL agent states, because the certificate, intention
# and login tests need it beside the ACLs.
set -euo pipefail

image=${CONSUL_IMAGE:-hashicorp/consul:1.20}
docker rm -f consul-it consul-it-acl >/dev/null 2>&1 || true

docker run -d --name consul-it --network host "$image" \
  agent -dev -client=127.0.0.1 -bind=127.0.0.1 >/dev/null

docker run -d --name consul-it-acl --network host "$image" \
  agent -dev -client=127.0.0.1 -bind=127.0.0.1 -node=acl -hcl '
    ports { http = 18500  dns = -1  grpc = -1  grpc_tls = -1  server = 18300  serf_lan = 18301  serf_wan = 18302 }
    connect { enabled = true }
    acl { enabled = true  default_policy = "deny"  tokens { initial_management = "moonconsul-root" } }
  ' >/dev/null

for port in 8500 18500; do
  for _ in $(seq 1 120); do
    if curl -fsS "http://127.0.0.1:$port/v1/status/leader" 2>/dev/null | grep -q ':'; then
      break
    fi
    sleep 0.5
  done
  curl -fsS "http://127.0.0.1:$port/v1/status/leader" | grep -q ':'
done

echo "consul agents are up"
