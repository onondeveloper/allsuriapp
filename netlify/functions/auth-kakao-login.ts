/// <reference types="node" />
// import { createClient } from "@supabase/supabase-js"; // ✅ 제거

const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string
const JWT_SECRET = process.env.JWT_SECRET || 'change_me'

export const handler = async (event: any) => {
  try {
    if (event.httpMethod !== 'POST') {
      return new Response(JSON.stringify({ message: 'Method Not Allowed' }), { status: 405, headers: { 'Content-Type': 'application/json' } });
    }
    const body = JSON.parse(event.body || '{}')
    const accessToken = body.access_token as string | undefined
    if (!accessToken) {
      return new Response(JSON.stringify({ message: 'access_token is required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
    }

    // Validate Kakao token and get profile
    const me = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    if (!me.ok) {
      const t = await me.text()
      return new Response(JSON.stringify({ message: 'Invalid Kakao token', detail: t }), { status: 401, headers: { 'Content-Type': 'application/json' } });
    }
    const kakao = await me.json()
    const kakaoId = String(kakao.id)
    const account = kakao.kakao_account || {}
    const profile = account.profile || {}
    
    // 카카오에서 제공하는 모든 정보 수집
    const email = account.email || '';
    let userId: string = ''; // userId를 let으로 단일 선언
    const name = profile.nickname || '카카오 사용자';
    const profileImage = profile.profile_image_url || profile.thumbnail_image_url || '';
    const phoneNumber = account.phone_number ? account.phone_number.replace(/\+82\s?/, '0').replace(/\s|-/g, '') : '';
    const ageRange = account.age_range || '';
    const birthday = account.birthday || '';
    const gender = account.gender || '';
    
    console.log('📱 카카오 사용자 정보 수집:', {
      kakaoId,
      name,
      email,
      hasProfileImage: !!profileImage,
      hasPhone: !!phoneNumber,
      ageRange,
      gender
    })

    // Persist/find user in Supabase (service role), prefer returning UUID id
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      const localId = `kakao:${kakaoId}`;
      // issueJwt 제거 및 에러 반환
      return new Response(JSON.stringify({ success: false, message: 'Supabase 환경 변수 누락', error: 'SUPABASE_ENV_MISSING' }), { status: 500, headers: { 'Content-Type': 'application/json' } });
    }

    let externalId = `kakao:${kakaoId}`
    const nowIso = new Date().toISOString()

    // 1) Try find by email first (most stable), else by external_id if column exists
    let row: any | null = null
    if (email) {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/users?email=eq.${encodeURIComponent(email)}&select=*`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const arr = await r.json()
      if (Array.isArray(arr) && arr.length > 0) row = arr[0]
    }
    if (!row) {
      const r2 = await fetch(`${SUPABASE_URL}/rest/v1/users?external_id=eq.${encodeURIComponent(externalId)}&select=*`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      if (r2.ok) {
        const arr2 = await r2.json()
        if (Array.isArray(arr2) && arr2.length > 0) row = arr2[0]
      }
    }

    // 2) If not found, insert minimal row (let Supabase generate UUID id). Include columns if they exist.
    if (!row) {
      const payload: Record<string, any> = {
        email: email || `kakao-${kakaoId}@allsuri.app`,
        name,
        role: 'customer',
        createdat: nowIso, // 소문자로 통일 (Supabase 테이블 스키마에 맞춤)
        provider: 'kakao',
        external_id: externalId,
        kakao_id: kakaoId, // 카카오 고유 ID
        profile_image: profileImage, // 프로필 이미지
        phonenumber: phoneNumber || null, // 전화번호
        age_range: ageRange || null, // 연령대
        birthday: birthday || null, // 생일
        gender: gender || null, // 성별
      }

      const ins = await fetch(`${SUPABASE_URL}/rest/v1/users`, {
        method: 'POST',
        headers: { 
          apikey: SUPABASE_SERVICE_ROLE_KEY, 
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 
          'Content-Type': 'application/json', 
          Prefer: 'return=representation' 
        },
        body: JSON.stringify(payload),
      })
      
      if (ins.ok) {
        const arr = await ins.json()
        row = Array.isArray(arr) ? arr[0] : arr
        console.log('✅ Supabase 사용자 생성 성공:', row?.id)
      } else {
        const errText = await ins.text()
        console.error('❌ Supabase 사용자 생성 실패:', ins.status, errText)
        
        // Fallback: UUID 생성하여 반환 (이 부분을 제거)
        // const crypto = require('crypto')
        // const uuid = crypto.randomUUID()
        // const token = await issueJwt(uuid)
        return new Response(JSON.stringify({ success: false, message: 'Supabase 사용자 생성 실패', error: errText }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
    } else {
      // 기존 사용자 정보 업데이트 (카카오 정보가 변경되었을 수 있음)
      const updatePayload: Record<string, any> = {
        name, // 최신 닉네임
      }
      
      // 프로필 이미지가 있으면 업데이트
      if (profileImage) {
        updatePayload.profile_image = profileImage
      }
      
      // 전화번호는 있을 때만 업데이트 (카카오에서 제공하지 않으면 기존 값 유지)
      if (phoneNumber && !row.phonenumber) {
        updatePayload.phonenumber = phoneNumber
      }
      
      // 카카오 ID가 없으면 추가
      if (!row.kakao_id) {
        updatePayload.kakao_id = kakaoId
      }
      
      // 업데이트할 내용이 있으면 실행
      if (Object.keys(updatePayload).length > 1) { // name 외에 다른 필드가 있으면
        const upd = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(row.id)}`, {
          method: 'PATCH',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            Prefer: 'return=representation',
          },
          body: JSON.stringify(updatePayload),
        })
        
        if (upd.ok) {
          const updated = await upd.json()
          row = Array.isArray(updated) && updated.length > 0 ? updated[0] : row
          console.log('✅ 카카오 정보 업데이트 성공:', row.id)
        }
      }
    }

    userId = row?.id || externalId; // 기존 userId에 값 할당
    const userRole = row?.role || 'customer'
    const businessStatus = row?.businessStatus || row?.businessstatus
    
    // Supabase Auth Admin API를 위한 정규화된 이메일 주소
    const supabaseAuthEmail = email && email.includes('@') && !email.includes('@example.local')
      ? email
      : `kakao-${kakaoId}@allsuri.app`;

    let supabaseAccessToken: string | null = null;
    let supabaseRefreshToken: string | null = null;
    
    console.log('[Kakao Login] 🔐 Supabase Auth 세션 생성 시작');
    console.log(`   - SUPABASE_URL: ${SUPABASE_URL ? '설정됨' : '❌ 없음'}`);
    console.log(`   - SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY ? '설정됨' : '❌ 없음'}`);
    console.log(`   - User ID: ${userId}`);
    console.log(`   - User Email (for Supabase Auth): ${supabaseAuthEmail}`);
    
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('❌ [Kakao Login] Supabase 환경 변수 누락!');
      console.log('   → Supabase Auth 세션 생성 건너뜀');
    } else {
      try {
        // 1. Supabase Auth 사용자가 존재하는지 확인
        let existingSupabaseUser: { id: string; email: string; } | null = null;
        let userAlreadyExists = false;

        try {
          const authAdminUsersUrl = `${SUPABASE_URL}/auth/v1/admin/users?email=eq.${supabaseAuthEmail}`;
          console.log(`   - Auth Admin URL (Check User): ${authAdminUsersUrl}`);
          const checkUserRes = await fetch(authAdminUsersUrl, {
            method: 'GET',
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            },
          });

          if (checkUserRes.ok) {
            const responseData = await checkUserRes.json();
            console.log(`🔍 [Kakao Login] Supabase Auth 조회 응답:`, JSON.stringify(responseData));
            
            // Supabase Auth Admin API는 { users: [...] } 형태로 반환할 수 있음
            const users = Array.isArray(responseData) ? responseData : (responseData.users || []);
            
            if (users && users.length > 0) {
              existingSupabaseUser = users[0];
              userAlreadyExists = true;
              if (existingSupabaseUser) {
                console.log(`✅ [Kakao Login] Supabase Auth 사용자 이미 존재: ${existingSupabaseUser.id}`);
                // 기존 사용자의 ID와 이메일을 사용하여 토큰 생성 단계로 바로 진행
                userId = existingSupabaseUser.id; // 기존 사용자 ID 사용
              }
              // 기존 사용자의 이메일이 다를 경우 업데이트 로직은 아래에서 처리
            } else {
              console.log('🔍 [Kakao Login] Supabase Auth 사용자 존재하지 않음.');
            }
          } else {
            console.log(`⚠️ [Kakao Login] Supabase Auth 사용자 확인 실패 (HTTP ${checkUserRes.status}): ${await checkUserRes.text()}`);
          }
        } catch (e: any) {
          console.log(`❌ [Kakao Login] Supabase Auth 사용자 확인 중 에러 발생: ${e.message}`);
        }

        if (!userAlreadyExists) {
          console.log('[Kakao Login] 2️⃣ Supabase Auth 사용자 생성 시도 중...');
          const createUserUrl = `${SUPABASE_URL}/auth/v1/admin/users`;
          console.log(`   - Create User URL: ${createUserUrl}`);
          const createUserBody = {
            email: supabaseAuthEmail,
            password: kakaoId, // 임시 비밀번호로 kakaoId 사용 (필요 시 더 강력한 방식 고려)
            email_confirm: true,
          };
          console.log(`   - Create User Request Body:`, createUserBody);

          const createUserRes = await fetch(createUserUrl, {
            method: 'POST',
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(createUserBody),
          });

          if (!createUserRes.ok) {
            const errorText = await createUserRes.text();
            console.warn(`[Kakao Login] Supabase Auth 사용자 생성 실패: ${errorText}`);
            
            // email_exists 오류인 경우, 다시 조회 시도
            try {
              const errorData = JSON.parse(errorText);
              if (errorData.error_code === 'email_exists') {
                console.log('🔄 [Kakao Login] email_exists 오류 감지. 기존 사용자 재조회 시도...');
                const retryCheckUserRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?email=eq.${supabaseAuthEmail}`, {
                  method: 'GET',
                  headers: {
                    apikey: SUPABASE_SERVICE_ROLE_KEY,
                    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                  },
                });
                
                if (retryCheckUserRes.ok) {
                  const retryResponseData = await retryCheckUserRes.json();
                  console.log(`🔍 [Kakao Login] 재조회 응답:`, JSON.stringify(retryResponseData));
                  const retryUsers = Array.isArray(retryResponseData) ? retryResponseData : (retryResponseData.users || []);
                  
                  if (retryUsers && retryUsers.length > 0) {
                    existingSupabaseUser = retryUsers[0];
                    if (existingSupabaseUser) {
                      userId = existingSupabaseUser.id;
                      userAlreadyExists = true;
                      console.log(`✅ [Kakao Login] 재조회 성공! 기존 사용자 ID: ${userId}`);
                    }
                  }
                }
              }
            } catch (parseError) {
              console.log(`⚠️ [Kakao Login] 오류 응답 파싱 실패:`, parseError);
            }
            
            // 재조회에도 실패한 경우에만 에러 반환
            if (!userAlreadyExists) {
              return new Response(JSON.stringify({
                success: false,
                message: 'Supabase Auth 사용자 생성 실패',
                error: errorText,
              }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
              });
            }
          } else {
            const createUserData = await createUserRes.json();
            userId = createUserData.id; // 새로 생성된 사용자 ID 사용
            console.log(`✅ [Kakao Login] Supabase Auth 사용자 생성 완료: ${userId}`);
          }
        } else if (existingSupabaseUser) { // existingSupabaseUser가 null이 아님을 보장
          // 이미 사용자가 존재하면, userId는 existingSupabaseUser.id로 설정됨
          console.log('🔍 [Kakao Login] 사용자 이미 존재하므로 생성 건너뜜.');
          
          // 기존 사용자의 비밀번호를 강제로 업데이트 (password grant 로그인을 위해)
          console.log(`🔄 [Kakao Login] 기존 사용자 비밀번호 업데이트 시도...`);
          const updateUserUrl = `${SUPABASE_URL}/auth/v1/admin/users/${existingSupabaseUser.id}`;
          const updateUserBody: Record<string, any> = { 
            password: kakaoId // 비밀번호를 kakaoId로 설정
          };
          
          // 이메일이 다르면 함께 업데이트
          if (existingSupabaseUser.email !== supabaseAuthEmail) {
            console.log(`⚠️ [Kakao Login] 기존 사용자 이메일(${existingSupabaseUser.email})도 업데이트합니다.`);
            updateUserBody.email = supabaseAuthEmail;
          }
          
          const updateRes = await fetch(updateUserUrl, {
            method: 'PUT',
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(updateUserBody),
          });

          if (updateRes.ok) {
            console.log(`✅ [Kakao Login] 사용자 정보 업데이트 완료 (비밀번호 & 이메일)`);
          } else {
            console.warn(`❌ [Kakao Login] 사용자 정보 업데이트 실패: ${await updateRes.text()}`);
            // 업데이트 실패해도 토큰 생성 시도
          }
        }


        // 3. 토큰 생성 (Generate Link)
        console.log('[Kakao Login] 3️⃣ 토큰 생성 중 (password grant)...');
        const tokenUrl = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
        console.log(`   - Token URL: ${tokenUrl}`);
        console.log(`   - User Email: ${supabaseAuthEmail}`);
        console.log(`   - User ID: ${userId}`);
        
        const tokenBody = {
          email: supabaseAuthEmail,
          password: kakaoId,
        };
        console.log(`   - Request Body:`, tokenBody);

        const tokenRes = await fetch(tokenUrl, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(tokenBody),
        });
        
        console.log(`   - 응답 상태: ${tokenRes.status} ${tokenRes.statusText}`);
        
        if (tokenRes.ok) {
          const tokenData = await tokenRes.json();
          console.log(`   - access_token 존재:`, tokenData.access_token ? 'O' : 'X');
          console.log(`   - refresh_token 존재:`, tokenData.refresh_token ? 'O' : 'X');
          
          supabaseAccessToken = tokenData.access_token || null;
          supabaseRefreshToken = tokenData.refresh_token || null;
          
          console.log('[Kakao Login] ✅ Supabase 세션 토큰 생성 성공');
          console.log(`   - Access Token: ${supabaseAccessToken ? `있음 (${supabaseAccessToken.substring(0, 20)}...)` : '❌ 없음'}`);
          console.log(`   - Refresh Token: ${supabaseRefreshToken ? `있음 (${supabaseRefreshToken.substring(0, 20)}...)` : '❌ 없음'}`);
        } else {
          const errText = await tokenRes.text();
          console.error('[Kakao Login] ❌ Supabase 토큰 생성 실패');
          console.error(`   - 상태: ${tokenRes.status}`);
          console.error(`   - 에러: ${errText}`);
          return new Response(JSON.stringify({ success: false, message: 'Supabase 토큰 생성 실패', error: errText }), { status: 500, headers: { 'Content-Type': 'application/json' } });
        }
      } catch (authErr: any) {
        console.error('[Kakao Login] ❌ Supabase Auth 처리 오류:', authErr.message);
        console.error(`   - 스택:`, authErr.stack);
        return new Response(JSON.stringify({ success: false, message: 'Supabase Auth 처리 오류', error: authErr.message }), { status: 500, headers: { 'Content-Type': 'application/json' } });
      }
    }
    
    console.log('[Kakao Login] 로그인 성공, userId:', userId);
    
    return new Response(JSON.stringify({
      success: true,
      message: 'Kakao login successful',
      data: {
        user: {
          id: userId,
          name: row?.name || name,
          email: supabaseAuthEmail,
          role: userRole,
          businessStatus: businessStatus,
          external_id: row?.external_id || externalId,
        },
        supabase_access_token: supabaseAccessToken,
        supabase_refresh_token: supabaseRefreshToken,
      },
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ message: 'Kakao login failed', error: String(e) }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }
}

