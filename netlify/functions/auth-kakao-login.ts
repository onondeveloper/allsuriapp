import type { Handler } from '@netlify/functions'

const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string
const JWT_SECRET = process.env.JWT_SECRET || 'change_me'

export const handler: Handler = async (event) => {
  try {
    if (event.httpMethod !== 'POST') {
      return { statusCode: 405, body: 'Method Not Allowed' }
    }
    const body = JSON.parse(event.body || '{}')
    const accessToken = body.access_token as string | undefined
    if (!accessToken) {
      return { statusCode: 400, body: JSON.stringify({ message: 'access_token is required' }) }
    }

    // TEST_BYPASS for emulator
    if (process.env.ALLOW_TEST_KAKAO === 'true' && accessToken === 'TEST_BYPASS') {
      const userId = 'kakao:test'
      const token = await issueJwt(userId)
      return ok({ 
        ok: true,
        success: true,
        token,
        data: {
          token,
          user: { id: userId, name: '카카오 테스트 사용자', email: 'kakao-test@allsuri.app' },
          supabase_access_token: null,
          supabase_refresh_token: null,
        }
      })
    }

    // Validate Kakao token and get profile
    const me = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${accessToken}` },
    })
    if (!me.ok) {
      const t = await me.text()
      return { statusCode: 401, body: JSON.stringify({ message: 'Invalid Kakao token', detail: t }) }
    }
    const kakao = await me.json()
    const kakaoId = String(kakao.id)
    const account = kakao.kakao_account || {}
    const profile = account.profile || {}
    
    // 카카오에서 제공하는 모든 정보 수집
    const email = account.email || ''
    const name = profile.nickname || '카카오 사용자'
    const profileImage = profile.profile_image_url || profile.thumbnail_image_url || ''
    const phoneNumber = account.phone_number ? account.phone_number.replace(/\+82\s?/, '0').replace(/\s|-/g, '') : ''
    const ageRange = account.age_range || ''
    const birthday = account.birthday || ''
    const gender = account.gender || ''
    
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
      const localId = `kakao:${kakaoId}`
      const token = await issueJwt(localId)
      return ok({ 
        ok: true,
        success: true,
        token,
        data: {
          token,
          user: { id: localId, name, email: email || `kakao-${kakaoId}@allsuri.app`, role: 'customer' },
          supabase_access_token: null,
          supabase_refresh_token: null,
        }
      })
    }

    const externalId = `kakao:${kakaoId}`
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
        
        // Fallback: UUID 생성하여 반환 (UUID 형식을 유지하여 이후 업데이트가 가능하도록)
        const crypto = require('crypto')
        const uuid = crypto.randomUUID()
        const token = await issueJwt(uuid)
        return ok({ 
          ok: true,
          success: true,
          token, 
          data: {
            token,
            user: { 
              id: uuid, 
              name, 
              email: email || `kakao-${kakaoId}@allsuri.app`, 
              role: 'customer',
              external_id: externalId,
              kakao_id: kakaoId,
            },
            supabase_access_token: null,
            supabase_refresh_token: null,
          },
          warning: 'supabase_insert_failed_using_temp_uuid' 
        })
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

    const userId = row?.id || externalId
    const userRole = row?.role || 'customer'
    const businessStatus = row?.businessStatus || row?.businessstatus
    const userEmail = row?.email || email || `kakao-${kakaoId}@allsuri.app`
    
    const token = await issueJwt(userId)
    
    // Supabase Auth Admin API를 사용하여 실제 세션 생성
    let supabaseAccessToken: string | null = null
    let supabaseRefreshToken: string | null = null
    
    console.log('[Kakao Login] 🔐 Supabase Auth 세션 생성 시작')
    console.log(`   - SUPABASE_URL: ${SUPABASE_URL ? '설정됨' : '❌ 없음'}`)
    console.log(`   - SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY ? '설정됨' : '❌ 없음'}`)
    console.log(`   - User ID: ${userId}`)
    console.log(`   - User Email: ${userEmail}`)
    
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      console.error('❌ [Kakao Login] Supabase 환경 변수 누락!')
      console.log('   → Supabase Auth 세션 생성 건너뜀')
    } else {
      try {
        // Supabase Admin API로 사용자 생성/업데이트 및 세션 발급
        const authAdminUrl = `${SUPABASE_URL}/auth/v1/admin/users`
        console.log(`   - Auth Admin URL: ${authAdminUrl}`)
        
        // 1. 사용자가 존재하는지 확인
        console.log('[Kakao Login] 1️⃣ 사용자 존재 확인 중...')
        const getUserRes = await fetch(`${authAdminUrl}?filter=id.eq.${userId}`, {
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        })
        
        console.log(`   - 응답 상태: ${getUserRes.status} ${getUserRes.statusText}`)
      
      if (getUserRes.ok) {
        const users = await getUserRes.json()
        if (users && users.users && users.users.length > 0) {
          console.log('[Kakao Login] Supabase Auth 사용자 존재:', userId)
        } else {
          // 2. 사용자 생성 (Supabase Auth)
          console.log('[Kakao Login] Supabase Auth 사용자 생성 시도:', userId)
          const createUserRes = await fetch(authAdminUrl, {
            method: 'POST',
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              id: userId,
              email: userEmail,
              email_confirm: true, // 이메일 확인 스킵
              user_metadata: {
                name: row?.name || name,
                provider: 'kakao',
                kakao_id: kakaoId,
              },
            }),
          })
          
          if (createUserRes.ok) {
            console.log('[Kakao Login] Supabase Auth 사용자 생성 성공')
          } else {
            const errText = await createUserRes.text()
            console.warn('[Kakao Login] Supabase Auth 사용자 생성 실패:', errText)
          }
        }
      }
      
        // 3. 토큰 생성 (Generate Link)
        console.log('[Kakao Login] 3️⃣ 토큰 생성 중...')
        const generateLinkUrl = `${SUPABASE_URL}/auth/v1/admin/generate_link`
        console.log(`   - Generate Link URL: ${generateLinkUrl}`)
        console.log(`   - Email: ${userEmail}`)
        
        const generateLinkRes = await fetch(generateLinkUrl, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            type: 'magiclink',
            email: userEmail,
          }),
        })
        
        console.log(`   - 응답 상태: ${generateLinkRes.status} ${generateLinkRes.statusText}`)
        
        if (generateLinkRes.ok) {
          const linkData = await generateLinkRes.json()
          console.log(`   - 응답 데이터 구조:`, Object.keys(linkData))
          console.log(`   - properties 존재:`, linkData.properties ? 'O' : 'X')
          
          supabaseAccessToken = linkData.properties?.access_token || null
          supabaseRefreshToken = linkData.properties?.refresh_token || null
          
          console.log('[Kakao Login] ✅ Supabase 세션 토큰 생성 성공')
          console.log(`   - Access Token: ${supabaseAccessToken ? `있음 (${supabaseAccessToken.substring(0, 20)}...)` : '❌ 없음'}`)
          console.log(`   - Refresh Token: ${supabaseRefreshToken ? `있음 (${supabaseRefreshToken.substring(0, 20)}...)` : '❌ 없음'}`)
        } else {
          const errText = await generateLinkRes.text()
          console.error('[Kakao Login] ❌ Supabase 토큰 생성 실패')
          console.error(`   - 상태: ${generateLinkRes.status}`)
          console.error(`   - 에러: ${errText}`)
        }
      } catch (authErr: any) {
        console.error('[Kakao Login] ❌ Supabase Auth 처리 오류:', authErr.message)
        console.error(`   - 스택:`, authErr.stack)
      }
    }
    
    console.log('[Kakao Login] 로그인 성공, userId:', userId)
    
    return ok({ 
      ok: true,
      success: true,
      token, 
      data: {
        token,
        user: { 
          id: userId, 
          name: row?.name || name, 
          email: userEmail, 
          role: userRole,
          businessStatus: businessStatus,
          external_id: row?.external_id || externalId,
        },
        supabase_access_token: supabaseAccessToken,
        supabase_refresh_token: supabaseRefreshToken,
      }
    })
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ message: 'Kakao login failed', error: String(e) }) }
  }
}

async function issueJwt(sub: string): Promise<string> {
  // Minimal JWT (HS256) without external deps
  const enc = (obj: any) => Buffer.from(JSON.stringify(obj)).toString('base64url')
  const header = enc({ alg: 'HS256', typ: 'JWT' })
  const payload = enc({ sub, iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30 })
  const data = `${header}.${payload}`
  const sig = require('crypto').createHmac('sha256', JWT_SECRET).update(data).digest('base64url')
  return `${data}.${sig}`
}

function ok(body: any) {
  return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
}

