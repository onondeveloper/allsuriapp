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

    // Dashboard aggregate (direct Supabase queries)
    if (event.httpMethod === 'GET' && path === '/dashboard') {
      const headers = { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` }
      
      // Fetch users
      const usersRes = await fetch(`${SUPABASE_URL}/rest/v1/users?select=role,businessstatus`, { headers })
      const users = await usersRes.json()
      const totalUsers = Array.isArray(users) ? users.length : 0
      const totalBusinessUsers = Array.isArray(users) ? users.filter((u: any) => u.role === 'business').length : 0
      const totalCustomers = Array.isArray(users) ? users.filter((u: any) => u.role === 'customer').length : 0
      const pendingBusinessUsers = Array.isArray(users) ? users.filter((u: any) => u.role === 'business' && u.businessstatus === 'pending').length : 0
      
      // Fetch estimates/orders (try both table names)
      let estimatesRes = await fetch(`${SUPABASE_URL}/rest/v1/estimates?select=status,estimatedPrice`, { headers })
      if (!estimatesRes.ok) {
        estimatesRes = await fetch(`${SUPABASE_URL}/rest/v1/orders?select=status,estimatedPrice`, { headers })
      }
      const estimates = await estimatesRes.json()
      const totalEstimates = Array.isArray(estimates) ? estimates.length : 0
      const pendingEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'pending').length : 0
      const approvedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'approved').length : 0
      const completedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'completed').length : 0
      const inProgressEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'in_progress').length : 0
      const awardedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'awarded').length : 0
      const transferredEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'transferred').length : 0
      const totalRevenue = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'completed').reduce((sum: number, e: any) => sum + ((e.estimatedPrice || 0) * 0.05), 0) : 0
      
      return ok({
        totalUsers,
        totalBusinessUsers,
        totalCustomers,
        approvedUsers: totalBusinessUsers - pendingBusinessUsers,
        totalEstimates,
        pendingEstimates,
        approvedEstimates,
        completedEstimates,
        inProgressEstimates,
        awardedEstimates,
        transferredEstimates,
        totalRevenue
      })
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
      
      // Supabase 테이블 컬럼명에 맞춤 (소문자)
      const updatePayload = { 
        businessstatus: status  // 소문자로 통일
      }
      
      const upRes = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`, {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify(updatePayload),
      })
      
      if (!upRes.ok) {
        const errText = await upRes.text()
        console.error('❌ 사용자 상태 업데이트 실패:', upRes.status, errText)
        return { statusCode: 500, body: JSON.stringify({ message: '상태 업데이트 실패', error: errText }) }
      }
      
      const updated = await upRes.json()
      console.log('✅ 사용자 상태 업데이트 성공:', userId, '→', status)
      return ok({ success: true, user: Array.isArray(updated) ? updated[0] : updated })
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

    // Market/Call listings
    if (path.startsWith('/market')) {
      const sub = path.replace(/^\/market/, '')
      if (event.httpMethod === 'GET' && (sub === '/listings' || sub.startsWith('/listings'))) {
        const qp = event.queryStringParameters || {}
        const status = qp.status || ''
        let url = `${SUPABASE_URL}/rest/v1/marketplace_listings?select=*`
        if (status && status !== 'all') {
          url += `&status=eq.${encodeURIComponent(status)}`
        }
        const res = await fetch(url, { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
        const json = await res.json()
        return ok(Array.isArray(json) ? json : [])
      }
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
