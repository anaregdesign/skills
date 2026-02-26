#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

WORKDIR_KEY_ENV="THEME_TEMPLATE_PPT_WORK_KEY"
FALLBACK_THREAD_ENV="CODEX_THREAD_ID"

normalize_key() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^[-._]+//; s/[-._]+$//')"
  printf '%s' "$cleaned"
}

generate_key() {
  local stamp token
  stamp="$(date +%Y%m%d-%H%M%S)"
  if command -v uuidgen >/dev/null 2>&1; then
    token="$(uuidgen | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+//g' | cut -c1-12)"
  else
    token="$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 12)"
  fi
  printf 'wk-%s-%s' "$stamp" "$token"
}

main() {
  local explicit="${1:-}"
  local source_key=""
  local source_label="generated"
  local normalized=""

  if [[ -n "$explicit" && "$explicit" != "ensure" ]]; then
    source_key="$explicit"
    source_label="arg"
  elif [[ -n "${THEME_TEMPLATE_PPT_WORK_KEY:-}" ]]; then
    source_key="${THEME_TEMPLATE_PPT_WORK_KEY}"
    source_label="env:${WORKDIR_KEY_ENV}"
  elif [[ -n "${CODEX_THREAD_ID:-}" ]]; then
    source_key="${CODEX_THREAD_ID}"
    source_label="env:${FALLBACK_THREAD_ENV}"
  fi

  if [[ -n "$source_key" ]]; then
    normalized="$(normalize_key "$source_key")"
  fi
  if [[ -z "$normalized" ]]; then
    normalized="$(generate_key)"
    source_label="generated"
  fi

  export THEME_TEMPLATE_PPT_WORK_KEY="$normalized"
  printf '[OK] %s=%s\n' "$WORKDIR_KEY_ENV" "$normalized"
  printf '[OK] source=%s\n' "$source_label"
}

main "$@"
