#!/bin/bash

# 올수리 앱 실행 스크립트
# 사용법: ./run_app.sh [dev|prod]

ENV=${1:-prod}

if [ "$ENV" == "dev" ]; then
    echo "🚀 개발 환경으로 앱 실행 중..."
    flutter run --dart-define-from-file=dart_defines.dev.json
elif [ "$ENV" == "prod" ]; then
    echo "🚀 프로덕션 환경으로 앱 실행 중..."
    flutter run --dart-define-from-file=dart_defines.json
else
    echo "❌ 잘못된 환경: $ENV"
    echo "사용법: ./run_app.sh [dev|prod]"
    exit 1
fi

