#!/bin/bash

# 올수리 앱 릴리즈 모드 기기 테스트 스크립트
# 사용법:
#   ./run_release.sh            → flutter run --release (로그 보면서 테스트)
#   ./run_release.sh install    → APK 빌드 후 adb로 직접 설치 (프로덕션과 동일)
#   ./run_release.sh dev        → 개발 환경으로 실행

MODE=${1:-run}
ENV=${2:-prod}

echo ""
echo "🚀 올수리 릴리즈 모드 실행"
echo "───────────────────────────────"

# dart_defines 파일 선택
if [ "$ENV" == "dev" ]; then
    DEFINES_FILE="dart_defines.dev.json"
    echo "🔧 환경: 개발 (dev)"
else
    DEFINES_FILE="dart_defines.json"
    echo "🚀 환경: 프로덕션 (prod)"
fi

if [ "$MODE" == "install" ]; then
    # ── APK 빌드 후 adb 직접 설치 (완전한 프로덕션 환경) ──────────────
    echo ""
    echo "📦 APK 빌드 중..."
    flutter build apk --release --dart-define-from-file=$DEFINES_FILE

    if [ $? -ne 0 ]; then
        echo "❌ APK 빌드 실패"
        exit 1
    fi

    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)

    echo ""
    echo "✅ APK 빌드 완료: $APK_SIZE"
    echo "📲 기기에 설치 중..."

    adb install -r "$APK_PATH"

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ 설치 완료!"
        echo "🚀 앱 실행 중..."
        adb shell am start -n com.ononcompany.allsuri/.MainActivity
        echo ""
        echo "💡 로그 보기: adb logcat | grep -i flutter"
    else
        echo "❌ 설치 실패 - 기기 연결 상태를 확인하세요"
        exit 1
    fi

else
    # ── flutter run --release (기본 - 로그 확인 가능) ─────────────────
    echo ""
    echo "📱 연결된 기기:"
    flutter devices
    echo ""
    echo "⚙️  릴리즈 빌드 실행 중... (처음 빌드는 시간이 걸립니다)"
    echo ""

    flutter run \
        --release \
        --dart-define-from-file=$DEFINES_FILE
fi
