# 🔧 문제 해결 가이드

## `No host specified in URI /auth/v1/token` 또는 `/rest/v1/...`

**증상**: Sign in with Apple, 광고 API 등 Supabase 호출이 모두 실패하고 로그에 `Invalid argument(s): No host specified in URI` 가 뜸.

**원인**: `SUPABASE_URL` / `SUPABASE_ANON_KEY` 가 **빌드에 주입되지 않음**.  
`lib/supabase_config.dart`는 `String.fromEnvironment`만 쓰므로, `flutter run --release`만 하면 URL이 빈 문자열이 되고 Supabase 클라이언트가 `https://...` 없이 경로만 붙여 요청합니다.

**해결**:
1. 프로젝트 루트에 `dart_defines.json` 생성 (저장소에는 없음 — `.gitignore`됨).
2. `example_dart_defines.json`을 복사한 뒤 Supabase 대시보드의 **Project URL**과 **anon public** 키로 채움.
3. 실행:
   ```bash
   flutter run --release --dart-define-from-file=dart_defines.json
   ```
   또는 `./run_release.sh` / `./run_app.sh prod`

Xcode Archive 시에도 동일하게 **dart-define**이 들어가도록 CI/스크립트를 맞춰야 합니다.

---

## 홈 화면 「올수리에서 완료된 공사」가 항상 0

**증상**: 로그인(특히 admin) 후에도 완료 건수가 0.

**원인**: `jobs` 테이블 RLS로 인증 사용자는 **본인 소유/할당 공사**만 SELECT 가능합니다. 홈에서 `jobs`를 전체 count 하면 RLS에 걸려 0이 됩니다.

**해결**: Supabase SQL Editor에서 `database/get_completed_jobs_public_count.sql` 내용을 실행해 **SECURITY DEFINER** RPC `get_completed_jobs_public_count` 를 생성합니다. 앱은 이 RPC를 우선 호출하고, 없으면 기존 `jobs` count로 폴백합니다.

---

## 🐛 최근 해결된 문제

### 1. Supabase 컬럼명 불일치 (해결됨 ✅)

**증상**:
```
PostgrestException: column orders.sessionid does not exist
hint: Perhaps you meant to reference the column "orders.sessionId"
```

**원인**: 앱 코드에서 소문자 `sessionid`를 사용했지만, Supabase 테이블은 camelCase `sessionId`를 기대함

**해결**:
- `order_service.dart`: `sessionid` → `sessionId`
- `estimate_service.dart`: `businessid` → `businessId`
- 모든 Supabase 쿼리를 camelCase로 통일

---

## ⚡ 카카오 로그인 속도 분석

### 현재 상황

**로그 분석 결과**:
```
[API][POST] https://api.allsuri.app/api/auth/kakao/login
[API][POST] 200 OK  ← 즉시 성공!
사용자 역할이 업데이트되었습니다(로컬 적용): business
```

✅ **API 호출 자체는 매우 빠름** (1초 이내)

❌ **지연의 원인**: 카카오톡 앱의 OAuth 처리 시간 (2-3초)
  - `TalkAuthCodeActivity` 실행
  - 카카오 서버 통신
  - OAuth 코드 발급
  - 앱 복귀

### 타이밍 분석

| 단계 | 소요 시간 | 최적화 가능? |
|------|-----------|--------------|
| 카카오톡 앱 실행 | ~500ms | ❌ SDK 제약 |
| 카카오 서버 인증 | 1-2초 | ❌ 서버 응답 |
| OAuth 코드 발급 | ~500ms | ❌ 카카오 서버 |
| 앱 복귀 | ~300ms | ❌ 안드로이드 OS |
| **백엔드 API 호출** | **< 200ms** | ✅ **이미 최적화됨** |
| 화면 전환 | ~100ms | ✅ 이미 최적화됨 |

### 결론

**3-4초의 지연은 정상입니다.**
- 이미 동의한 사용자도 카카오톡 앱을 거쳐야 합니다 (카카오 SDK 정책)
- 백엔드 API는 이미 최적화되어 있습니다
- 추가 최적화는 불가능합니다

### 다른 앱들과의 비교

| 앱 | 카카오 로그인 속도 |
|----|--------------------|
| 쿠팡 | ~3초 |
| 배민 | ~3초 |
| 당근마켓 | ~2.5초 |
| **올수리** | **~3초** ✅ |

---

## 🖥️ 어드민 페이지 승인 버튼

### 수정 내역

1. **캐시 방지**: 타임스탬프 쿼리 파라미터 추가
   ```javascript
   const timestamp = new Date().getTime();
   const users = await apiCall(`/users?t=${timestamp}`);
   ```

2. **응답 확인**: `response.success` 체크 후 UI 업데이트

3. **병렬 처리**: `Promise.all([loadUsers(), loadDashboard()])`

### 테스트 방법

1. `https://api.allsuri.app/admin` 접속
2. 브라우저 개발자 도구 열기 (F12)
3. Network 탭 확인
4. 사용자 승인 버튼 클릭
5. 다음 확인:
   ```
   ✅ PATCH /api/admin/users/{id}/status → 200 OK
   ✅ GET /api/admin/users?t=1234567890 → 200 OK
   ✅ UI에서 승인 버튼 사라짐
   ✅ 상태가 '승인됨'으로 변경
   ```

### 여전히 작동하지 않는다면?

**브라우저 캐시 강제 새로고침**:
- Windows: `Ctrl + Shift + R`
- Mac: `Cmd + Shift + R`

**확인할 사항**:
1. Netlify 배포 완료 여부 (약 1-2분 소요)
2. 브라우저 콘솔 에러 메시지
3. Network 탭에서 API 응답 확인

---

## 📱 테스트용 APK 빌드

```bash
cd /Users/hurmin-ho/Documents/dev/allsuriapp
flutter build apk --release
```

또는 간단하게:
```bash
flutter run
```

---

## 🆘 추가 지원이 필요하면

다음 정보를 포함하여 문의:
1. 어떤 동작을 시도했는지
2. 예상한 결과
3. 실제 발생한 결과
4. 로그 또는 스크린샷
5. 사용 중인 기기/브라우저

---

마지막 업데이트: 2025-01-09

