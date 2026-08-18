#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
cd "$project_root"

app_path="$project_root/build/Codex Usage Peek.app"
build_root="$project_root/.build/manual-release"
module_cache="$build_root/module-cache"

if [[ -n "${CODEX_USAGE_SDK_PATH:-}" ]]; then
  sdk_path="$CODEX_USAGE_SDK_PATH"
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  sdk_path=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
else
  sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi

if [[ "$sdk_path" == /Library/Developer/CommandLineTools/* ]]; then
  swiftc_path=/Library/Developer/CommandLineTools/usr/bin/swiftc
else
  swiftc_path="$(xcrun --find swiftc)"
fi

mkdir -p "$build_root" "$module_cache"

"$swiftc_path" \
  -sdk "$sdk_path" \
  -module-cache-path "$module_cache" \
  -target arm64-apple-macosx13.0 \
  -O \
  -emit-module \
  -emit-library \
  -module-name CodexUsageCore \
  -Xlinker -install_name \
  -Xlinker @rpath/libCodexUsageCore.dylib \
  "$project_root"/Sources/CodexUsageCore/*.swift \
  -emit-module-path "$build_root/CodexUsageCore.swiftmodule" \
  -o "$build_root/libCodexUsageCore.dylib"

"$swiftc_path" \
  -sdk "$sdk_path" \
  -module-cache-path "$module_cache" \
  -target arm64-apple-macosx13.0 \
  -O \
  -parse-as-library \
  -I "$build_root" \
  -L "$build_root" \
  -lCodexUsageCore \
  -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks \
  "$project_root"/Sources/CodexUsagePeek/*.swift \
  -o "$build_root/CodexUsagePeek"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Frameworks"
cp "$build_root/CodexUsagePeek" "$app_path/Contents/MacOS/CodexUsagePeek"
cp "$build_root/libCodexUsageCore.dylib" "$app_path/Contents/Frameworks/libCodexUsageCore.dylib"
cp "$project_root/Config/CodexUsagePeek-Info.plist" "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path/Contents/Frameworks/libCodexUsageCore.dylib"
codesign --force --sign - "$app_path/Contents/MacOS/CodexUsagePeek"
codesign --force --sign - "$app_path"

echo "$app_path"
