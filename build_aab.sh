#!/bin/bash

# 올수리 앱 AAB 빌드 스크립트
# 사용법: ./build_aab.sh [dev|prod] [build_number]

ENV=${1:-prod}
BUILD_NUMBER=${2:-}

if [ "$ENV" == "dev" ]; then
    echo "🔨 개발 환경 AAB 빌드 중..."
    if [ -n "$BUILD_NUMBER" ]; then
        flutter build appbundle --dart-define-from-file=dart_defines.dev.json --build-number=$BUILD_NUMBER
    else
        flutter build appbundle --dart-define-from-file=dart_defines.dev.json
    fi
elif [ "$ENV" == "prod" ]; then
    echo "🚀 프로덕션 환경 AAB 빌드 중..."
    if [ -n "$BUILD_NUMBER" ]; then
        flutter build appbundle --dart-define-from-file=dart_defines.json --build-number=$BUILD_NUMBER
    else
        flutter build appbundle --dart-define-from-file=dart_defines.json
    fi
else
    echo "❌ 잘못된 환경: $ENV"
    echo "사용법: ./build_aab.sh [dev|prod] [build_number]"
    exit 1
fi

echo ""
echo "✅ AAB 빌드 완료!"
echo "📁 파일 위치: build/app/outputs/bundle/release/app-release.aab"
echo "📏 파일 크기: $(du -h build/app/outputs/bundle/release/app-release.aab | cut -f1)"
echo ""
echo "📤 Google Play Console에 업로드할 준비가 완료되었습니다!"
