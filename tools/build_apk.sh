#!/usr/bin/env bash
# 안드로이드 APK 만들기 (export/android/demo.apk).
# Google 사이트에서 Android SDK 를 받을 수 없는 환경이라, GitHub 의 uber-apk-signer 안에 든
# Google apksigner 로 최소한의 SDK 폴더를 만들어 Godot 가 서명하게 한다.
# 필요: Godot, Android 내보내기 템플릿(android_release.apk), Java(keytool)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="${ANDROID_SDK:-$HOME/Android/Sdk}"
BT="$SDK/build-tools/33.0.2"
KEYSTORE="$ROOT/tools/android/demo.keystore"
# 데모 배포용 서명 키 (공개 저장소에는 올리지 않음, .gitignore). 없으면 새로 만든다
# → 키가 바뀌면 폰에 깔린 예전 앱 위에 덮어 설치가 안 되니 지우고 다시 설치
KEY_ALIAS="demo"
KEY_PASS="demo-apk"

if [ ! -x "$BT/apksigner" ]; then
	echo "서명 도구 준비..."
	WORK="$(mktemp -d)"
	curl -sSL -o "$WORK/uber.jar" https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar
	mkdir -p "$BT/lib" "$SDK/platform-tools"
	(cd "$WORK" && unzip -o -q uber.jar lib/apksigner_33_0_2.jar)
	cp "$WORK/lib/apksigner_33_0_2.jar" "$BT/lib/apksigner.jar"
	printf '#!/usr/bin/env bash\nexec java -jar "$(dirname "$0")/lib/apksigner.jar" "$@"\n' > "$BT/apksigner"
	chmod +x "$BT/apksigner"
	# Godot 가 있는지만 확인하는 adb (기기 설치는 하지 않음)
	printf '#!/usr/bin/env bash\necho "adb 없음 (APK 만들기 전용 SDK)" >&2\nexit 1\n' > "$SDK/platform-tools/adb"
	chmod +x "$SDK/platform-tools/adb"
	rm -rf "$WORK"
fi

if [ ! -f "$KEYSTORE" ]; then
	keytool -genkeypair -v -keystore "$KEYSTORE" -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
		-storepass "$KEY_PASS" -keypass "$KEY_PASS" -dname "CN=demo" >/dev/null 2>&1
fi

# Godot 편집기 설정의 SDK 경로를 맞춘다
SETTINGS="$(ls "$HOME"/.config/godot/editor_settings-4*.tres | head -1)"
sed -i "s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"$SDK\"|" "$SETTINGS"

mkdir -p export/android
godot --headless --path . --import >/dev/null 2>&1 || true
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEY_PASS" \
	godot --headless --path . --export-release "Android" export/android/demo.apk 2>&1 | grep -E "ERROR|error" || true
"$BT/apksigner" verify export/android/demo.apk
ls -la export/android/demo.apk
