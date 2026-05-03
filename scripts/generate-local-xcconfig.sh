#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="${1:-local}"
output_mode="${2:-write}"

case "$profile" in
  local)
    bundle_identifier="com.avalsys.avphotosys.dev"
    ;;
  production)
    bundle_identifier="com.avalsys.avphotosys"
    ;;
  *)
    echo "Unsupported profile: $profile" >&2
    exit 1
    ;;
esac

eval "$("$repo_root/scripts/resolve-infisical-bootstrap-env.sh" "$profile")"

varlock_bin="$repo_root/node_modules/.bin/varlock"

if [ ! -x "$varlock_bin" ]; then
  echo "varlock CLI is required. Run 'bun install' in $repo_root." >&2
  exit 1
fi

printenv_value() {
  local key="$1"
  "$varlock_bin" printenv --path "$repo_root/" "$key" 2>/dev/null || true
}

xcodebuild_url_value() {
  local value="$1"
  # xcconfig treats `//` as a comment start, so URLs must escape the second slash.
  printf '%s' "$value" | sed 's#//#/$()/#g'
}

account_publishable_key="$(printenv_value AVACCOUNT_PUBLISHABLE_KEY)"
avaccount_api_base_url="$(printenv_value AVACCOUNT_API_BASE_URL)"
if [ -z "${avaccount_api_base_url:-}" ] && [ "$profile" = "local" ]; then
  avaccount_api_base_url="http://127.0.0.1:8788"
fi
support_email="$(printenv_value AVPHOTOSYS_SUPPORT_EMAIL)"
account_management_url="$(printenv_value AVACCOUNT_MANAGEMENT_URL)"
terms_url="$(printenv_value AVPHOTOSYS_TERMS_URL)"
privacy_url="$(printenv_value AVPHOTOSYS_PRIVACY_URL)"
open_source_url="$(printenv_value AVPHOTOSYS_OPEN_SOURCE_URL)"
premium_product_ids="$(printenv_value AVPHOTOSYS_PREMIUM_PRODUCT_IDS)"
development_team="$(printenv_value AVALSYS_APPLE_DEVELOPMENT_TEAM)"

if [ -z "${open_source_url:-}" ]; then
  open_source_url="https://github.com/miguelavalos/av-photosys"
fi

required_values=(
  account_publishable_key
  avaccount_api_base_url
  support_email
  account_management_url
  terms_url
  privacy_url
)

for value_name in "${required_values[@]}"; do
  if [ -z "${!value_name:-}" ]; then
    echo "Missing required value from Infisical: $value_name" >&2
    exit 1
  fi
done

rendered_config="$(cat <<EOF
AVPHOTOSYS_BUNDLE_IDENTIFIER = $bundle_identifier
AVALSYS_APPLE_DEVELOPMENT_TEAM = $development_team
AVACCOUNT_PUBLISHABLE_KEY = $account_publishable_key
AVACCOUNT_API_BASE_URL = $(xcodebuild_url_value "${avaccount_api_base_url:-}")
AVPHOTOSYS_SUPPORT_EMAIL = ${support_email:-}
AVACCOUNT_MANAGEMENT_URL = $(xcodebuild_url_value "${account_management_url:-}")
AVPHOTOSYS_TERMS_URL = $(xcodebuild_url_value "${terms_url:-}")
AVPHOTOSYS_PRIVACY_URL = $(xcodebuild_url_value "${privacy_url:-}")
AVPHOTOSYS_OPEN_SOURCE_URL = $(xcodebuild_url_value "$open_source_url")
AVPHOTOSYS_PREMIUM_PRODUCT_IDS = ${premium_product_ids:-}
EOF
)"

target_file="$repo_root/apps/ios/Config/Local.xcconfig"

case "$output_mode" in
  write)
    umask 077
    printf '%s\n' "$rendered_config" > "$target_file"
    echo "Wrote $target_file for profile '$profile'."
    ;;
  stdout)
    printf '%s\n' "$rendered_config"
    ;;
  *)
    echo "Unsupported output mode: $output_mode" >&2
    exit 1
    ;;
esac
