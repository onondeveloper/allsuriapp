# Sign in with Apple (App Store Guideline 4.8)

앱은 카카오 로그인과 **동등한** 로그인으로 **Sign in with Apple**을 제공합니다 (iOS/iPadOS).

## 1. Xcode

1. **Signing & Capabilities** → **+ Capability** → **Sign in with Apple** 추가  
2. `ios/Runner/Runner.entitlements`에 `com.apple.developer.applesignin`이 포함되어 있는지 확인 (저장소에 반영됨)

## 2. Apple Developer

- App ID에 **Sign In with Apple** 활성화  
- (필요 시) Services ID, Sign in with Apple용 Key 생성 — [Apple 문서](https://developer.apple.com/sign-in-with-apple/) 참고

## 3. Supabase

1. Dashboard → **Authentication** → **Providers** → **Apple**  
2. **Enable** 후 Apple에서 발급한 **Services ID (Client ID)**, **Secret Key**(또는 JWT 생성 방식), **Team ID** 등을 입력  
3. Redirect URL은 Supabase 안내에 맞게 설정  

설정이 없으면 앱에서 Apple 로그인 버튼을 눌렀을 때 Supabase 쪽에서 검증 실패할 수 있습니다.

## 4. App Store Connect 답변 예시 (심사용)

> We have implemented **Sign in with Apple** as an equivalent login option alongside Kakao.  
> Sign in with Apple limits data to name/email, supports **Hide My Email**, and does not use the login for third-party advertising without user consent, consistent with Guideline 4.8.

스크린샷은 로그인 화면에 **Apple 로그인 버튼**이 보이도록 업데이트하세요.
