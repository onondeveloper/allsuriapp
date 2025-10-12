#!/bin/bash

# 올수리 APK 빌드 스크립트
# 사용법: ./build_apk.sh [prod|dev]

ENV=${1:-prod}

if [ "$ENV" == "dev" ]; then
    echo "🔨 개발 환경으로 APK 빌드 중..."
    flutter build apk --dart-define-from-file=dart_defines.dev.json
elif [ "$ENV" == "prod" ]; then
    echo "🔨 프로덕션 환경으로 APK 빌드 중..."
    flutter build apk --dart-define-from-file=dart_defines.json
else
    echo "❌ 잘못된 환경: $ENV"
    echo "사용법: ./build_apk.sh [dev|prod]"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "✅ APK 빌드 완료!"
    echo "📦 위치: build/app/outputs/flutter-apk/app-release.apk"
else
    echo "❌ APK 빌드 실패"
    exit 1
fi

