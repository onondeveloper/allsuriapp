/// <reference types="node" />
// Netlify Function: FCM 푸시 알림 전송
// POST /api/notifications/send-push
// Authorization: Bearer <supabase_jwt>
// Body: { userId, title, body, data? }

const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string
const FIREBASE_SERVICE_ACCOUNT_KEY = process.env.FIREBASE_SERVICE_ACCOUNT_KEY as string

const JSON_HEADERS = { 'Content-Type': 'application/json' }

// Firebase Admin 싱글톤 (Lambda 콜드 스타트 당 1회 초기화)
let _firebaseMessaging: any = null

function getMessaging() {
  if (_firebaseMessaging) return _firebaseMessaging
  if (!FIREBASE_SERVICE_ACCOUNT_KEY) {
    console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT_KEY 환경 변수 없음 - FCM 비활성화')
    return null
  }
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const admin = require('firebase-admin')
    if (!admin.apps.length) {
      const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_KEY)
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) })
      console.log('✅ Firebase Admin SDK 초기화 완료')
    }
    _firebaseMessaging = admin.messaging()
    return _firebaseMessaging
  } catch (e: any) {
    console.error('❌ Firebase Admin 초기화 실패:', e.message)
    return null
  }
}

export const handler = async (event: any) => {
  // CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 204,
      headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization' },
      body: '',
    }
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: JSON.stringify({ error: 'Method Not Allowed' }), headers: JSON_HEADERS }
  }

  try {
    // ── 1. JWT 인증 ──────────────────────────────────────────────────────
    const authHeader = (event.headers['authorization'] || event.headers['Authorization'] || '') as string
    const token = authHeader.replace(/^Bearer\s+/i, '').trim()

    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Authorization header required' }), headers: JSON_HEADERS }
    }

    // Supabase JWT 검증 (service role로 /auth/v1/user 호출)
    const verifyRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${token}`,
      },
    })

    if (!verifyRes.ok) {
      console.warn('[send-push] JWT 검증 실패:', verifyRes.status)
      return { statusCode: 401, body: JSON.stringify({ error: 'Invalid or expired token' }), headers: JSON_HEADERS }
    }

    // ── 2. 요청 파싱 ────────────────────────────────────────────────────
    const body = JSON.parse(event.body || '{}')
    const { userId, title, body: msgBody, data = {} } = body

    if (!userId || !title || !msgBody) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'userId, title, body are required' }),
        headers: JSON_HEADERS,
      }
    }

    // ── 3. 수신자 FCM 토큰 조회 ─────────────────────────────────────────
    const userRes = await fetch(
      `${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}&select=fcm_token`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    )

    const users = await userRes.json()
    const fcmToken: string | null = Array.isArray(users) && users[0]?.fcm_token ? users[0].fcm_token : null

    if (!fcmToken) {
      console.log(`ℹ️ [send-push] userId=${userId} FCM 토큰 없음 - 푸시 스킵`)
      return {
        statusCode: 200,
        body: JSON.stringify({ sent: false, reason: 'no_fcm_token' }),
        headers: JSON_HEADERS,
      }
    }

    // ── 4. 읽지 않은 알림 수 조회 (iOS 뱃지용) ──────────────────────────
    let unreadCount = 1
    try {
      const unreadRes = await fetch(
        `${SUPABASE_URL}/rest/v1/notifications?userid=eq.${encodeURIComponent(userId)}&isread=eq.false&select=id`,
        { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } }
      )
      const unreadData = await unreadRes.json()
      // 현재 미읽음 수 + 이번 알림 1개
      unreadCount = (Array.isArray(unreadData) ? unreadData.length : 0) + 1
    } catch (e) {
      console.warn('[send-push] 미읽음 수 조회 실패 (badge=1 사용):', e)
    }

    // ── 5. FCM 전송 ─────────────────────────────────────────────────────
    const messaging = getMessaging()
    if (!messaging) {
      console.error('[send-push] Firebase 미설정 - FIREBASE_SERVICE_ACCOUNT_KEY 환경변수를 Netlify 대시보드에서 확인하세요')
      return {
        statusCode: 200,
        body: JSON.stringify({ sent: false, reason: 'firebase_not_configured' }),
        headers: JSON_HEADERS,
      }
    }

    // 데이터 값은 모두 string이어야 함 (FCM 요구사항)
    const safeData: Record<string, string> = {}
    for (const [k, v] of Object.entries(data)) {
      safeData[k] = String(v ?? '')
    }
    safeData['sentAt'] = new Date().toISOString()
    safeData['badge'] = String(unreadCount)

    await messaging.send({
      token: fcmToken,
      notification: { title, body: msgBody },
      data: safeData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'allsuri_notifications',
          sound: 'default',
          notificationCount: unreadCount, // Android 뱃지 숫자
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: unreadCount, // iOS 뱃지 숫자 (실제 미읽음 수)
          },
        },
      },
    })

    console.log(`✅ [send-push] 푸시 전송 성공: userId=${userId}, badge=${unreadCount}`)
    return {
      statusCode: 200,
      body: JSON.stringify({ sent: true }),
      headers: JSON_HEADERS,
    }
  } catch (e: any) {
    // FCM 토큰이 만료/무효인 경우 DB에서 제거
    if (
      e?.code === 'messaging/invalid-registration-token' ||
      e?.code === 'messaging/registration-token-not-registered'
    ) {
      const body = JSON.parse(event.body || '{}')
      console.log(`⚠️ [send-push] 만료된 FCM 토큰 제거: userId=${body.userId}`)
      await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${body.userId}`, {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fcm_token: null }),
      })
      return {
        statusCode: 200,
        body: JSON.stringify({ sent: false, reason: 'token_expired_removed' }),
        headers: JSON_HEADERS,
      }
    }

    console.error('[send-push] 오류:', e)
    return {
      statusCode: 500,
      body: JSON.stringify({ error: e.message || 'Internal Server Error' }),
      headers: JSON_HEADERS,
    }
  }
}
