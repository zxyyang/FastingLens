#!/bin/bash
set -e

# ============================================================
# FastingLens 一键构建 & 部署脚本
# 证书过期后在 Mac 上运行此脚本即可重新安装到 iPhone + Watch
# ============================================================

TEAM_ID="87NDQ6Q8C7"
SCHEME="FastingLens"
ARCHIVE_PATH="$HOME/Desktop/FastingLens.xcarchive"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

IPHONE_UDID="FC2BC738-9AA3-5457-8F98-BC0863FFD1CA"
WATCH_UDID="F6A52272-2C2E-55D6-8CFA-E8D6CB45B85E"

echo "📦 构建 FastingLens ..."
cd "$PROJECT_DIR"
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  2>&1 | tail -5

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "❌ 构建失败"; exit 1
fi
echo "✅ 构建成功"

echo ""
echo "📱 安装到 iPhone ..."
xcrun devicectl device install app \
  --device "$IPHONE_UDID" \
  "$ARCHIVE_PATH/Products/Applications/FastingLens.app" 2>&1
echo "✅ iPhone 安装完成"

echo ""
echo "⌚ 安装到 Apple Watch ..."
echo "   (请确保 Watch 亮屏且与 Mac 在同一 WiFi)"
RETRY=0
MAX_RETRY=3
while [ $RETRY -lt $MAX_RETRY ]; do
  if xcrun devicectl device install app \
    --device "$WATCH_UDID" \
    "$ARCHIVE_PATH/Products/Applications/FastingLens.app/Watch/FastingLens Watch.app" 2>&1; then
    echo "✅ Watch 安装完成"
    break
  else
    RETRY=$((RETRY + 1))
    if [ $RETRY -lt $MAX_RETRY ]; then
      echo "⚠️  Watch 连接失败，5秒后重试 ($RETRY/$MAX_RETRY) ..."
      sleep 5
    else
      echo "❌ Watch 安装失败，请确认 Watch 网络连接后手动重试："
      echo "   xcrun devicectl device install app --device $WATCH_UDID \"$ARCHIVE_PATH/Products/Applications/FastingLens.app/Watch/FastingLens Watch.app\""
    fi
  fi
done

echo ""
echo "🎉 部署完成！"
echo "   iPhone + Watch 都已安装最新版本"
echo "   开发者签名有效期 7 天，到期后重新运行此脚本即可"
