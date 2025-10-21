#!/bin/bash

# 카카오 로그인을 위한 키 해시 추출 스크립트
# 이 스크립트는 debug와 release 키스토어의 키 해시를 추출합니다.

echo "=================================================="
echo "카카오 로그인 키 해시 추출"
echo "=================================================="
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Android 디렉토리로 이동
cd "$(dirname "$0")/android"

echo -e "${BLUE}1. Debug 키 해시 (개발용)${NC}"
echo "=================================================="

# Debug 키스토어 위치 (일반적으로 ~/.android/debug.keystore)
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ -f "$DEBUG_KEYSTORE" ]; then
    echo "Debug keystore: $DEBUG_KEYSTORE"
    DEBUG_HASH=$(keytool -exportcert -alias androiddebugkey -keystore "$DEBUG_KEYSTORE" -storepass android -keypass android 2>/dev/null | openssl sha1 -binary | openssl base64)
    echo -e "${GREEN}Debug 키 해시:${NC}"
    echo -e "${YELLOW}$DEBUG_HASH${NC}"
    echo ""
else
    echo -e "${RED}Debug keystore를 찾을 수 없습니다: $DEBUG_KEYSTORE${NC}"
    echo ""
fi

echo -e "${BLUE}2. Release 키 해시 (배포용) - 가장 중요!${NC}"
echo "=================================================="

# Release 키스토어 위치
RELEASE_KEYSTORE="upload-keystore.jks"

if [ -f "$RELEASE_KEYSTORE" ]; then
    echo "Release keystore: $RELEASE_KEYSTORE"
    echo ""
    echo "키스토어 비밀번호를 입력하세요 (key.properties의 storePassword):"
    
    # 키 해시 추출
    RELEASE_HASH=$(keytool -exportcert -alias allsuri -keystore "$RELEASE_KEYSTORE" 2>/dev/null | openssl sha1 -binary | openssl base64)
    
    if [ $? -eq 0 ] && [ -n "$RELEASE_HASH" ]; then
        echo ""
        echo -e "${GREEN}✅ Release 키 해시 (이것을 카카오 개발자 콘솔에 등록하세요!):${NC}"
        echo -e "${YELLOW}$RELEASE_HASH${NC}"
        echo ""
        echo -e "${RED}⚠️  이 키 해시를 반드시 카카오 개발자 콘솔에 등록해야 합니다!${NC}"
    else
        echo -e "${RED}키 해시 추출에 실패했습니다. 비밀번호를 확인하세요.${NC}"
    fi
    echo ""
else
    echo -e "${RED}Release keystore를 찾을 수 없습니다: $RELEASE_KEYSTORE${NC}"
    echo "경로: $(pwd)/$RELEASE_KEYSTORE"
    echo ""
fi

echo "=================================================="
echo -e "${BLUE}3. 카카오 개발자 콘솔 설정 방법${NC}"
echo "=================================================="
echo "1. https://developers.kakao.com 접속"
echo "2. 내 애플리케이션 > 올수리 선택"
echo "3. 플랫폼 > Android 플랫폼 설정"
echo "4. 패키지명: com.ononcompany.allsuri"
echo "5. 키 해시: 위에서 출력된 Release 키 해시 등록"
echo "   (여러 개 등록 가능, 줄바꿈으로 구분)"
echo ""
echo -e "${YELLOW}주의: Debug와 Release 키 해시가 다릅니다!${NC}"
echo -e "${YELLOW}배포 시에는 반드시 Release 키 해시를 등록해야 합니다.${NC}"
echo "=================================================="

