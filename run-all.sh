#!/usr/bin/env bash
set -euo pipefail

env_args=()
if [[ -f .env ]]; then
  env_args+=(--env-file .env)
fi

axp run "${env_args[@]}" ./chctl-discovery-install.yaml
axp run "${env_args[@]}" ./chctl-local-db.yaml
axp run "${env_args[@]}" ./chctl-cloud-move.yaml
