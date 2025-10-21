#!/bin/bash

# Google Play Console 앱 서명 확인 및 키 해시 추출 스크립트

echo "=================================================="
echo "Google Play Console 앱 서명 확인"
echo "=================================================="
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Google Play Console에서 확인해야 할 사항:${NC}"
echo "=================================================="
echo "1. Play Console > 앱 무결성 > 앱 서명"
echo "2. 'Google에서 관리하는 앱 서명 키' 사용 중인지 확인"
echo "3. '앱 서명 키 인증서' 섹션에서 SHA-1 인증서 지문 확인"
echo ""

echo -e "${BLUE}📱 현재 로컬 키스토어 키 해시:${NC}"
echo "=================================================="

# Android 디렉토리로 이동
cd "$(dirname "$0")/android"

# Release 키스토어 위치
RELEASE_KEYSTORE="upload-keystore.jks"

if [ -f "$RELEASE_KEYSTORE" ]; then
    echo "로컬 Release keystore: $RELEASE_KEYSTORE"
    echo ""
    echo "키스토어 비밀번호를 입력하세요:"
    
    # 키 해시 추출
    RELEASE_HASH=$(keytool -exportcert -alias allsuri -keystore "$RELEASE_KEYSTORE" 2>/dev/null | openssl sha1 -binary | openssl base64)
    
    if [ $? -eq 0 ] && [ -n "$RELEASE_HASH" ]; then
        echo ""
        echo -e "${GREEN}✅ 로컬 Release 키 해시:${NC}"
        echo -e "${YELLOW}$RELEASE_HASH${NC}"
        echo ""
    else
        echo -e "${RED}키 해시 추출에 실패했습니다.${NC}"
    fi
else
    echo -e "${RED}Release keystore를 찾을 수 없습니다: $RELEASE_KEYSTORE${NC}"
fi

echo ""
echo "=================================================="
echo -e "${BLUE}🚨 중요: Google Play Console 앱 서명 확인${NC}"
echo "=================================================="
echo ""
echo -e "${YELLOW}Google Play Console에서 다음을 확인하세요:${NC}"
echo ""
echo "1. Play Console > 올수리 > 앱 무결성 > 앱 서명"
echo "2. '앱 서명 키 인증서' 섹션에서:"
echo "   - SHA-1 인증서 지문을 복사"
echo "   - 이 SHA-1을 Base64로 변환"
echo ""
echo "3. SHA-1을 Base64로 변환하는 방법:"
echo "   - SHA-1 (예: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD)"
echo "   - 콜론(:) 제거: AABBCCDDEEFF00112233445566778899AABBCCDD"
echo "   - Hex를 Base64로 변환"
echo ""
echo "4. 변환된 Base64 키 해시를 카카오 개발자 콘솔에 추가 등록"
echo ""
echo -e "${RED}⚠️  로컬 키스토어와 Google Play Console의 키가 다를 수 있습니다!${NC}"
echo -e "${RED}   Google Play Console의 실제 키 해시를 등록해야 합니다.${NC}"
echo ""

echo "=================================================="
echo -e "${BLUE}🛠️  해결 방법:${NC}"
echo "=================================================="
echo ""
echo "1. Play Console에서 SHA-1 인증서 지문 복사"
echo "2. 온라인 도구로 SHA-1 → Base64 변환:"
echo "   https://base64.guru/converter/encode/hex"
echo "3. 변환된 Base64 키 해시를 카카오 개발자 콘솔에 추가"
echo "4. 기존 로컬 키 해시도 함께 유지"
echo ""
echo -e "${GREEN}이렇게 하면 개발용(로컬)과 배포용(Play Console) 키 모두 지원됩니다.${NC}"
echo ""

echo "=================================================="
echo -e "${BLUE}📋 카카오 개발자 콘솔에 등록할 키 해시 목록:${NC}"
echo "=================================================="
echo ""
echo "1. Debug 키 해시 (개발용):"
echo "   tpsjWyfccHas3NiOWup11jF7lTQ="
echo ""
echo "2. 로컬 Release 키 해시 (업로드용):"
echo "   zNb2GVsO4wQ8B9y3IFPGoaxi2r0="
echo ""
echo "3. Google Play Console SHA-1 → Base64 변환한 키 해시 (실제 배포용)"
echo "   ← 이 값을 Play Console에서 가져와서 변환하세요!"
echo ""
