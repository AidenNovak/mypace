#!/usr/bin/env bash
#
# Deploy MyPace marketing site to Cloudflare Pages.
# Requires: wrangler 4.x + authenticated session (wrangler login)
#           OR CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID in env.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="${MYPACE_PAGES_PROJECT:-mypace}"
BRANCH="${MYPACE_PAGES_BRANCH:-main}"

if ! command -v wrangler >/dev/null 2>&1; then
  echo "❌ wrangler not found. Install: npm i -g wrangler"
  exit 1
fi

echo "──────────────────────────────────────────"
echo "  Cloudflare Pages · ${PROJECT_NAME}"
echo "  directory: ${SCRIPT_DIR}"
echo "──────────────────────────────────────────"

# Optional: create project if missing (ignore error if exists)
wrangler pages project create "$PROJECT_NAME" --production-branch "$BRANCH" 2>/dev/null || true

COMMIT_HASH=""
COMMIT_MSG=""
if git -C "$(dirname "$SCRIPT_DIR")" rev-parse HEAD >/dev/null 2>&1; then
  COMMIT_HASH="$(git -C "$(dirname "$SCRIPT_DIR")" rev-parse HEAD)"
  COMMIT_MSG="$(git -C "$(dirname "$SCRIPT_DIR")" log -1 --pretty=%s)"
fi

wrangler pages deploy . \
  --project-name "$PROJECT_NAME" \
  --branch "$BRANCH" \
  ${COMMIT_HASH:+--commit-hash "$COMMIT_HASH"} \
  ${COMMIT_MSG:+--commit-message "$COMMIT_MSG"}

echo ""
echo "✅ Deployed. Open Cloudflare dashboard → Workers & Pages → ${PROJECT_NAME} for the *.pages.dev URL."
