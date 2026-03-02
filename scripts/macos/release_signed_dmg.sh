#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_NAME="Tokentrack"
SWIFT_PRODUCT_NAME="${SWIFT_PRODUCT_NAME:-TokscaleMac}"
BUNDLE_ID="${BUNDLE_ID:-io.tokentrack.mac}"
MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-14.0}"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$ROOT_DIR/Cargo.toml" | head -n 1)"
fi

if [[ -z "$VERSION" ]]; then
  echo "Error: unable to resolve version from argument or Cargo.toml"
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE_DIR="$DIST_DIR/${APP_NAME}.app"
DMG_STAGING_DIR="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/${APP_NAME}-v${VERSION}-macos-arm64.dmg"
ZIP_PATH="$DIST_DIR/${APP_NAME}-v${VERSION}-macos-arm64.zip"

RUST_BIN="$ROOT_DIR/target/release/tokscale"
SWIFT_BIN="$ROOT_DIR/apps/TokscaleMac/.build/release/${SWIFT_PRODUCT_NAME}"

SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
ALLOW_UNSIGNED_RELEASE="${ALLOW_UNSIGNED_RELEASE:-true}"

ALLOW_UNSIGNED_RELEASE="$(printf '%s' "$ALLOW_UNSIGNED_RELEASE" | tr '[:upper:]' '[:lower:]')"
if [[ "$ALLOW_UNSIGNED_RELEASE" != "true" && "$ALLOW_UNSIGNED_RELEASE" != "false" ]]; then
  echo "Error: ALLOW_UNSIGNED_RELEASE must be true or false"
  exit 1
fi

RESOLVED_SIGNING_IDENTITY=""
SIGNED_ARTIFACTS="false"

tmp_notary_key=""
cleanup() {
  if [[ -n "$tmp_notary_key" && -f "$tmp_notary_key" ]]; then
    rm -f "$tmp_notary_key"
  fi
}
trap cleanup EXIT

warn() {
  echo "Warning: $*"
}

resolve_signing_identity() {
  local identity_output
  identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  if [[ -n "$SIGNING_IDENTITY" ]]; then
    if printf '%s\n' "$identity_output" | grep -Fq "$SIGNING_IDENTITY"; then
      RESOLVED_SIGNING_IDENTITY="$SIGNING_IDENTITY"
      echo "Using SIGNING_IDENTITY from environment: $SIGNING_IDENTITY"
      return 0
    fi
    warn "SIGNING_IDENTITY '$SIGNING_IDENTITY' was not found in keychain. Falling back to auto-discovery."
  fi

  local selected_hash=""
  local selected_label=""
  while IFS= read -r line; do
    [[ "$line" == *"Developer ID Application:"* ]] || continue

    local hash
    hash="$(printf '%s\n' "$line" | awk '{print $2}')"
    local label
    label="$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*[0-9][0-9]*[)] [0-9A-F]\{40\} "\(Developer ID Application:.*\)"/\1/p')"

    [[ -n "$hash" && -n "$label" ]] || continue

    if [[ -n "$APPLE_TEAM_ID" && "$label" != *"(${APPLE_TEAM_ID})"* ]]; then
      continue
    fi

    selected_hash="$hash"
    selected_label="$label"
    break
  done <<< "$identity_output"

  if [[ -n "$selected_hash" ]]; then
    RESOLVED_SIGNING_IDENTITY="$selected_hash"
    echo "Auto-selected signing identity: $selected_label"
    if [[ -n "$APPLE_TEAM_ID" ]]; then
      echo "Team filter: $APPLE_TEAM_ID"
    fi
    return 0
  fi

  return 1
}

echo "[1/6] Build Rust CLI"
cd "$ROOT_DIR"
cargo build --release -p tokscale-cli

echo "[2/6] Build Swift app (release)"
(
  cd "$ROOT_DIR/apps/TokscaleMac"
  swift build -c release
)

echo "[3/6] Create app bundle"
rm -rf "$APP_BUNDLE_DIR"
mkdir -p "$APP_BUNDLE_DIR/Contents/MacOS" "$APP_BUNDLE_DIR/Contents/Resources"

cp "$SWIFT_BIN" "$APP_BUNDLE_DIR/Contents/MacOS/${APP_NAME}"
cp "$RUST_BIN" "$APP_BUNDLE_DIR/Contents/Resources/tokscale"
chmod +x "$APP_BUNDLE_DIR/Contents/MacOS/${APP_NAME}" "$APP_BUNDLE_DIR/Contents/Resources/tokscale"

cat > "$APP_BUNDLE_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS_VERSION}</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

echo "[4/6] Sign app and binaries"
if resolve_signing_identity; then
  set +e
  codesign --force --timestamp --options runtime --sign "$RESOLVED_SIGNING_IDENTITY" "$APP_BUNDLE_DIR/Contents/Resources/tokscale"
  sign_cli_status=$?
  if [[ $sign_cli_status -eq 0 ]]; then
    codesign --force --timestamp --options runtime --sign "$RESOLVED_SIGNING_IDENTITY" "$APP_BUNDLE_DIR"
    sign_app_status=$?
  else
    sign_app_status=1
  fi
  if [[ $sign_cli_status -eq 0 && $sign_app_status -eq 0 ]]; then
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_DIR"
    verify_status=$?
  else
    verify_status=1
  fi
  set -e

  if [[ $sign_cli_status -eq 0 && $sign_app_status -eq 0 && $verify_status -eq 0 ]]; then
    SIGNED_ARTIFACTS="true"
    echo "App signing complete."
  elif [[ "$ALLOW_UNSIGNED_RELEASE" == "true" ]]; then
    warn "codesign failed. Continuing with unsigned artifacts (Gatekeeper warning expected)."
  else
    echo "Error: codesign failed and ALLOW_UNSIGNED_RELEASE=false"
    exit 1
  fi
else
  if [[ "$ALLOW_UNSIGNED_RELEASE" == "true" ]]; then
    warn "No usable Developer ID Application identity found. Continuing with unsigned artifacts (Gatekeeper warning expected)."
  else
    echo "Error: no usable Developer ID Application identity found and ALLOW_UNSIGNED_RELEASE=false"
    exit 1
  fi
fi

echo "[5/6] Create ZIP and DMG"
mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH"
rm -rf "$DMG_STAGING_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE_DIR" "$ZIP_PATH"

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_BUNDLE_DIR" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_PATH"

if [[ "$SIGNED_ARTIFACTS" == "true" ]]; then
  set +e
  codesign --force --timestamp --sign "$RESOLVED_SIGNING_IDENTITY" "$DMG_PATH"
  sign_dmg_status=$?
  set -e
  if [[ $sign_dmg_status -ne 0 ]]; then
    if [[ "$ALLOW_UNSIGNED_RELEASE" == "true" ]]; then
      warn "DMG signing failed. Continuing with unsigned DMG (Gatekeeper warning expected)."
      SIGNED_ARTIFACTS="false"
    else
      echo "Error: DMG signing failed and ALLOW_UNSIGNED_RELEASE=false"
      exit 1
    fi
  fi
fi

echo "[6/6] Notarize and staple (if credentials exist)"
has_api_key="false"
if [[ -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
  if [[ -n "${APPLE_NOTARY_PRIVATE_KEY:-}" || -n "${APPLE_NOTARY_PRIVATE_KEY_BASE64:-}" ]]; then
    has_api_key="true"
  fi
fi

has_apple_id="false"
if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  has_apple_id="true"
fi

if [[ "$SIGNED_ARTIFACTS" == "true" ]]; then
  if [[ "$has_api_key" == "true" ]]; then
    tmp_notary_key="$(mktemp "$ROOT_DIR/.notary_key.XXXXXX.p8")"
    if [[ -n "${APPLE_NOTARY_PRIVATE_KEY:-}" ]]; then
      printf "%s" "$APPLE_NOTARY_PRIVATE_KEY" > "$tmp_notary_key"
    else
      printf "%s" "${APPLE_NOTARY_PRIVATE_KEY_BASE64:-}" | base64 --decode > "$tmp_notary_key"
    fi
    xcrun notarytool submit "$DMG_PATH" --key "$tmp_notary_key" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --wait
    xcrun stapler staple "$APP_BUNDLE_DIR"
    xcrun stapler staple "$DMG_PATH"
  elif [[ "$has_apple_id" == "true" ]]; then
    xcrun notarytool submit "$DMG_PATH" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
    xcrun stapler staple "$APP_BUNDLE_DIR"
    xcrun stapler staple "$DMG_PATH"
  else
    echo "Notarization skipped. Missing notarization credentials."
  fi
else
  echo "Notarization skipped. Artifacts are unsigned."
fi

echo "Artifacts:"
echo "  $APP_BUNDLE_DIR"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
