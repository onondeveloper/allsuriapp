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
      return ok({ token, user: { id: userId, name: '카카오 테스트 사용자', email: 'kakao_test@example.local' } })
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
    const email = account.email || ''
    const name = (account.profile && account.profile.nickname) || '카카오 사용자'

    // Persist/find user in Supabase (service role), prefer returning UUID id
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      const localId = `kakao:${kakaoId}`
      const token = await issueJwt(localId)
      return ok({ token, user: { id: localId, name, email: email || `${localId}@example.local`, role: 'customer' } })
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
        email: email || `${externalId}@example.local`,
        name,
        role: 'customer',
        createdat: nowIso, // 소문자로 통일 (Supabase 테이블 스키마에 맞춤)
        provider: 'kakao',
        external_id: externalId,
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
          token, 
          user: { 
            id: uuid, 
            name, 
            email: email || `${externalId}@example.local`, 
            role: 'customer',
            external_id: externalId,
          }, 
          warning: 'supabase_insert_failed_using_temp_uuid' 
        })
      }
    }

    const userId = row?.id || externalId
    const userRole = row?.role || 'customer'
    const businessStatus = row?.businessStatus || row?.businessstatus
    
    const token = await issueJwt(userId)
    return ok({ 
      token, 
      user: { 
        id: userId, 
        name: row?.name || name, 
        email: row?.email || email || `${externalId}@example.local`, 
        role: userRole,
        businessStatus: businessStatus,
        external_id: row?.external_id || externalId,
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


