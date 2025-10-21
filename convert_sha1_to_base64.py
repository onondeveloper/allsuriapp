#!/usr/bin/env python3
"""
SHA-1 인증서 지문을 Base64 키 해시로 변환하는 스크립트
Google Play Console의 SHA-1을 카카오 로그인용 키 해시로 변환합니다.
"""

import sys
import base64

def sha1_to_base64_key_hash(sha1_string):
    """
    SHA-1 인증서 지문을 Base64 키 해시로 변환
    
    Args:
        sha1_string: SHA-1 인증서 지문 (예: "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD")
    
    Returns:
        Base64 키 해시 문자열
    """
    # 콜론(:) 제거
    hex_string = sha1_string.replace(':', '').replace(' ', '').upper()
    
    # Hex 문자열을 바이트로 변환
    try:
        hex_bytes = bytes.fromhex(hex_string)
    except ValueError as e:
        raise ValueError(f"Invalid hex string: {e}")
    
    # Base64로 인코딩
    base64_hash = base64.b64encode(hex_bytes).decode('utf-8')
    
    return base64_hash

def main():
    print("==================================================")
    print("SHA-1 → Base64 키 해시 변환기")
    print("==================================================")
    print("")
    
    if len(sys.argv) > 1:
        sha1_input = sys.argv[1]
    else:
        print("Google Play Console에서 복사한 SHA-1 인증서 지문을 입력하세요:")
        print("예: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD")
        print("")
        sha1_input = input("SHA-1: ").strip()
    
    if not sha1_input:
        print("❌ SHA-1이 입력되지 않았습니다.")
        return
    
    try:
        base64_hash = sha1_to_base64_key_hash(sha1_input)
        
        print("")
        print("✅ 변환 완료!")
        print("==================================================")
        print(f"입력 SHA-1: {sha1_input}")
        print(f"Base64 키 해시: {base64_hash}")
        print("==================================================")
        print("")
        print("📋 카카오 개발자 콘솔에 등록할 키 해시:")
        print("1. Debug 키 해시 (개발용):")
        print("   tpsjWyfccHas3NiOWup11jF7lTQ=")
        print("")
        print("2. 로컬 Release 키 해시 (업로드용):")
        print("   zNb2GVsO4wQ8B9y3IFPGoaxi2r0=")
        print("")
        print("3. Google Play Console 키 해시 (배포용):")
        print(f"   {base64_hash}")
        print("")
        print("🔗 https://developers.kakao.com > 내 애플리케이션 > 올수리 > 플랫폼 > Android")
        print("   위 3개의 키 해시를 모두 등록하세요!")
        
    except ValueError as e:
        print(f"❌ 오류: {e}")
        print("")
        print("올바른 SHA-1 형식 예시:")
        print("AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD")

if __name__ == "__main__":
    main()
