#!/bin/bash

# 테스트용 APK 빌드 스크립트
# 카카오 로그인과 API 연결을 테스트하기 위한 디버그 빌드

echo "🔨 올수리 앱 테스트 빌드 시작..."

# 필수 환경 변수 확인
if [ -z "$KAKAO_NATIVE_APP_KEY" ]; then
  echo "⚠️  경고: KAKAO_NATIVE_APP_KEY 환경 변수가 설정되지 않았습니다."
  echo "   export KAKAO_NATIVE_APP_KEY=your_key_here"
fi

if [ -z "$SUPABASE_URL" ]; then
  echo "⚠️  경고: SUPABASE_URL 환경 변수가 설정되지 않았습니다."
fi

# Flutter 빌드 (디버그 모드, 테스트 바이패스 활성화)
flutter build apk --debug \
  --dart-define=KAKAO_NATIVE_APP_KEY=${KAKAO_NATIVE_APP_KEY:-9462c73fdeaba67181aadcc46af6d293} \
  --dart-define=SUPABASE_URL=${SUPABASE_URL:-https://sggwqbfhlzvhfmdbfjwo.supabase.co} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNnZ3dxYmZobHp2aGZtZGJmandvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMzk4MTcsImV4cCI6MjA1NjgxNTgxN30.mREJwN5qgnMCh7H8Qtr8Nt2Q5hNJ7ivhXfx22pcdvkI} \
  --dart-define=API_BASE_URL=https://api.allsuri.app/api \
  --dart-define=ALLOW_TEST_KAKAO=true

if [ $? -eq 0 ]; then
  echo "✅ 빌드 성공!"
  echo "📦 APK 위치: build/app/outputs/flutter-apk/app-debug.apk"
  
  # 파일 크기 확인
  APK_SIZE=$(ls -lh build/app/outputs/flutter-apk/app-debug.apk | awk '{print $5}')
  echo "📊 파일 크기: $APK_SIZE"
  
  # public 폴더로 복사 (배포용)
  cp build/app/outputs/flutter-apk/app-debug.apk public/allsuri-test.apk
  echo "📤 public/allsuri-test.apk 로 복사 완료"
else
  echo "❌ 빌드 실패"
  exit 1
fi

