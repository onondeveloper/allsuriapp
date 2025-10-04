// Netlify function: admin API router
// Proxies selected endpoints used by backend/public/admin.js
import type { Handler } from '@netlify/functions'

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || process.env.ADMIN_DEVELOPER_TOKEN || 'devtoken'
const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string

function unauthorized() {
  return { statusCode: 401, body: JSON.stringify({ message: '관리자 권한이 필요합니다' }) }
}

function withAuth(headers: Record<string, string>): boolean {
  const token = headers['admin-token'] || headers['x-admin-token'] || ''
  return token === ADMIN_TOKEN
}

export const handler: Handler = async (event) => {
  try {
    // method/path
    const path = (() => {
      const p = event.path || '/'
      const a = p.replace(/^\/\.netlify\/functions\/admin/, '')
      const b = a.replace(/^\/api\/admin/, '')
      return b || '/'
    })()

    if (!withAuth(event.headers as any)) {
      return unauthorized()
    }

    // Dashboard aggregate (minimal mock via Supabase counts)
    if (event.httpMethod === 'GET' && path === '/dashboard') {
      const counts = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_dashboard_counts`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      })
      if (!counts.ok) {
        // Fallback: zero metrics
        return ok({ totalUsers: 0, totalBusinessUsers: 0, totalCustomers: 0, pendingEstimates: 0, totalEstimates: 0, completedEstimates: 0 })
      }
      const data = await counts.json()
      return ok(data)
    }

    // Admin me
    if (event.httpMethod === 'GET' && path === '/me') {
      return ok({ role: 'developer', permissions: { canManageUsers: true, canManageAds: true } })
    }

    // Users list (from Supabase)
    if (event.httpMethod === 'GET' && path === '/users') {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/users?select=*`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const json = await res.json()
      return ok(Array.isArray(json) ? json : [])
    }

    // Users search
    if (event.httpMethod === 'GET' && path.startsWith('/users/search')) {
      const q = new URLSearchParams(event.queryStringParameters as any).get('q') || ''
      const like = encodeURIComponent(`%${q}%`)
      const url = `${SUPABASE_URL}/rest/v1/users?or=(name.ilike.${like},email.ilike.${like})`
      const res = await fetch(url, { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
      const json = await res.json()
      return ok(Array.isArray(json) ? json : [])
    }

    // User status update
    if (event.httpMethod === 'PATCH' && path.startsWith('/users/') && path.endsWith('/status')) {
      const userId = path.split('/')[2]
      const body = JSON.parse(event.body || '{}')
      const status = body.status || 'pending'
      const { ok: upOk } = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`, {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ businessStatus: status }),
      })
      if (!upOk) return { statusCode: 500, body: JSON.stringify({ message: '상태 업데이트 실패' }) }
      return ok({ success: true })
    }

    // DELETE user
    if (event.httpMethod === 'DELETE' && path.startsWith('/users/')) {
      const userId = path.split('/')[2]
      const del = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`, {
        method: 'DELETE',
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      if (!del.ok) return { statusCode: 500, body: JSON.stringify({ message: '삭제 실패' }) }
      return ok({ success: true })
    }

    // Estimates list
    if (event.httpMethod === 'GET' && path.startsWith('/estimates')) {
      const qs = (() => {
        const qp = event.queryStringParameters || {}
        const sp = new URLSearchParams()
        for (const [k, v] of Object.entries(qp)) if (v != null) sp.append(k, String(v))
        const s = sp.toString()
        return s ? `?${s}` : ''
      })()
      const sep = qs ? (qs.includes('?') ? '&' : '?') : '?'
      const res = await fetch(`${SUPABASE_URL}/rest/v1/estimates${qs}${sep}select=*`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const json = await res.json()
      return ok(Array.isArray(json) ? json : [])
    }

    // Estimate status update
    if (event.httpMethod === 'PATCH' && path.startsWith('/estimates/') && path.endsWith('/status')) {
      const estimateId = path.split('/')[2]
      const body = JSON.parse(event.body || '{}')
      const status = body.status
      const res = await fetch(`${SUPABASE_URL}/rest/v1/estimates?id=eq.${encodeURIComponent(estimateId)}`, {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ status }),
      })
      if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '견적 상태 업데이트 실패' }) }
      return ok({ success: true })
    }

    // Ads endpoints via Supabase
    if (path.startsWith('/ads')) {
      const sub = path.replace(/^\/ads/, '')
      if (event.httpMethod === 'GET' && (sub === '' || sub === '/')) {
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?select=*`, { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
        const json = await res.json()
        return ok(Array.isArray(json) ? json : [])
      }
      if (event.httpMethod === 'POST' && (sub === '' || sub === '/')) {
        const payload = JSON.parse(event.body || '{}')
        payload.createdat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads`, {
          method: 'POST',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 생성 실패' }) }
        return ok(await res.json())
      }
      if (event.httpMethod === 'PUT' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const payload = JSON.parse(event.body || '{}')
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
          body: JSON.stringify(payload),
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 업데이트 실패' }) }
        return ok(await res.json())
      }
      if (event.httpMethod === 'DELETE' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 삭제 실패' }) }
        return ok({ success: true })
      }
    }

    return { statusCode: 404, body: 'Not Found' }
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ message: 'Admin function error', error: String(e) }) }
  }
}

function ok(body: any) {
  return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
}
