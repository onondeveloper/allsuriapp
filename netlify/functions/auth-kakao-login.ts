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

    // Upsert into Supabase (service role)
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      // If supabase not configured, still issue app JWT to allow frontend flow
      const uid = `kakao:${kakaoId}`
      const token = await issueJwt(uid)
      return ok({ token, user: { id: uid, name, email: email || `${uid}@example.local` } })
    }
    const uid = `kakao:${kakaoId}`
    const up = await fetch(`${SUPABASE_URL}/rest/v1/users`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        Prefer: 'resolution=merge-duplicates',
      },
      body: JSON.stringify({ id: uid, email: email || `${uid}@example.local`, name, role: 'customer', createdAt: new Date().toISOString() }),
    })
    if (!up.ok) {
      const t = await up.text()
      return { statusCode: 500, body: JSON.stringify({ message: 'Supabase upsert failed', detail: t }) }
    }

    const token = await issueJwt(uid)
    return ok({ token, user: { id: uid, name, email: email || `${uid}@example.local` } })
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


