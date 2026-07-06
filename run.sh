#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="lakera-redteam"
RESULTS_DIR="${SCRIPT_DIR}/results"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Required:
  --lakera-key    <key>   Lakera API key
  --litellm-url   <url>   LiteLLM base URL  (default: http://host.docker.internal:4000)
  --litellm-key   <key>   LiteLLM API key   (default: anything)
  --model         <name>  Model name to test (default: gpt-3.5-turbo)

Optional settings are read from .env in the same directory.
Results are written to ./results/scan_results.json

Example:
  $(basename "$0") --lakera-key lk-xxx --litellm-url http://host.docker.internal:4000 --litellm-key sk-yyy --model gpt-4o
EOF
  exit 1
}

LAKERA_API_KEY=""
LITELLM_BASE_URL="http://host.docker.internal:4000"
LITELLM_API_KEY="anything"
LITELLM_MODEL="gpt-3.5-turbo"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lakera-key)   LAKERA_API_KEY="$2";   shift 2 ;;
    --litellm-url)  LITELLM_BASE_URL="$2"; shift 2 ;;
    --litellm-key)  LITELLM_API_KEY="$2";  shift 2 ;;
    --model)        LITELLM_MODEL="$2";    shift 2 ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$LAKERA_API_KEY" ]]; then
  echo "Error: --lakera-key is required."
  usage
fi

mkdir -p "$RESULTS_DIR"

echo "Building image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

echo "Starting red team scan..."
echo "  Target LiteLLM : $LITELLM_BASE_URL"
echo "  Model          : $LITELLM_MODEL"
echo "  Results dir    : $RESULTS_DIR"
echo ""

docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  --env-file "${SCRIPT_DIR}/.env" \
  -e LAKERA_API_KEY="$LAKERA_API_KEY" \
  -e LITELLM_BASE_URL="$LITELLM_BASE_URL" \
  -e LITELLM_API_KEY="$LITELLM_API_KEY" \
  -e LITELLM_MODEL="$LITELLM_MODEL" \
  -e RESULTS_FILE=/results/scan_results.json \
  -v "${RESULTS_DIR}:/results" \
  "$IMAGE_NAME"

echo ""
echo "Scan complete. Results saved to: ${RESULTS_DIR}/scan_results.json"
