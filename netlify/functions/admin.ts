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
      
      // Fetch estimates (use amount column, not estimatedPrice)
      const estimatesRes = await fetch(`${SUPABASE_URL}/rest/v1/estimates?select=status,amount`, { headers })
      const estimates = await estimatesRes.json()
      
      console.log('[ADMIN DASHBOARD] Estimates count:', Array.isArray(estimates) ? estimates.length : 0)
      console.log('[ADMIN DASHBOARD] Estimates sample:', Array.isArray(estimates) ? estimates.slice(0, 5) : [])
      
      const totalEstimates = Array.isArray(estimates) ? estimates.length : 0
      const pendingEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'pending').length : 0
      const approvedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'approved').length : 0
      const completedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'completed').length : 0
      const inProgressEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'in_progress').length : 0
      const awardedEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'awarded').length : 0
      const transferredEstimates = Array.isArray(estimates) ? estimates.filter((e: any) => e.status === 'transferred').length : 0
      
      // 완료된 견적의 총 금액 계산
      // completed, awarded, transferred 상태의 견적 모두 포함
      const completedStatuses = ['completed', 'awarded', 'transferred']
      const completedEstimatesList = Array.isArray(estimates) 
        ? estimates.filter((e: any) => completedStatuses.includes(e.status)) 
        : []
      
      const totalEstimateAmount = completedEstimatesList.reduce((sum: number, e: any) => {
        const amount = e.amount || 0
        console.log(`[ADMIN DASHBOARD] Estimate amount: ${amount}, status: ${e.status}`)
        return sum + amount
      }, 0)
      
      console.log('[ADMIN DASHBOARD] Total estimate amount:', totalEstimateAmount)
      console.log('[ADMIN DASHBOARD] Completed estimates count:', completedEstimatesList.length)
      
      // 총 수익: 완료된 견적 금액의 5% 계산
      const totalRevenue = totalEstimateAmount * 0.05
      
      // Fetch marketplace_listings (오더 현황)
      const listingsRes = await fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?select=id,status,claimed_by`, { headers })
      const listings = await listingsRes.json()
      console.log('[ADMIN DASHBOARD] Listings count:', Array.isArray(listings) ? listings.length : 0)
      console.log('[ADMIN DASHBOARD] Listings sample:', Array.isArray(listings) ? listings.slice(0, 3) : [])
      
      const totalOrders = Array.isArray(listings) ? listings.length : 0
      // 입찰 중: status가 'created' 또는 'open'이고 아직 claimed_by가 없는 경우
      const pendingOrders = Array.isArray(listings) 
        ? listings.filter((l: any) => (l.status === 'created' || l.status === 'open') && !l.claimed_by).length 
        : 0
      // 완료: status가 'assigned'이거나 claimed_by가 있는 경우
      const completedOrders = Array.isArray(listings) 
        ? listings.filter((l: any) => l.status === 'assigned' || l.claimed_by).length 
        : 0
      
      console.log('[ADMIN DASHBOARD] Orders - Total:', totalOrders, 'Pending:', pendingOrders, 'Completed:', completedOrders)
      
      // Fetch jobs (기존 jobs 테이블)
      const jobsRes = await fetch(`${SUPABASE_URL}/rest/v1/jobs?select=id,status`, { headers })
      const jobs = await jobsRes.json()
      const totalJobs = Array.isArray(jobs) ? jobs.length : 0
      const pendingJobs = Array.isArray(jobs) ? jobs.filter((j: any) => j.status === 'pending').length : 0
      const completedJobs = Array.isArray(jobs) ? jobs.filter((j: any) => j.status === 'completed').length : 0
      
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
        totalEstimateAmount: Math.round(totalEstimateAmount),
        totalRevenue: Math.round(totalRevenue),
        totalOrders,
        pendingOrders,
        completedOrders,
        totalJobs,
        pendingJobs,
        completedJobs
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

    // Call 공사 목록 (jobs 테이블)
    if (event.httpMethod === 'GET' && path === '/calls') {
      const jobsRes = await fetch(`${SUPABASE_URL}/rest/v1/jobs?select=*&order=created_at.desc`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const jobs = await jobsRes.json()
      
      if (!Array.isArray(jobs)) {
        return ok([])
      }
      
      // 사업자 정보 가져오기
      const ownerIds = [...new Set(jobs.map((j: any) => j.owner_business_id).filter(Boolean))]
      const assignedIds = [...new Set(jobs.map((j: any) => j.assigned_business_id).filter(Boolean))]
      const allUserIds = [...new Set([...ownerIds, ...assignedIds])]
      
      let usersMap: Record<string, any> = {}
      if (allUserIds.length > 0) {
        const usersRes = await fetch(`${SUPABASE_URL}/rest/v1/users?select=id,name,businessname,phonenumber&id=in.(${allUserIds.map(id => `"${id}"`).join(',')})`, {
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
        })
        const users = await usersRes.json()
        if (Array.isArray(users)) {
          usersMap = users.reduce((acc: any, user: any) => {
            acc[user.id] = user
            return acc
          }, {})
        }
      }
      
      // 사업자 정보를 포함한 데이터 반환
      const jobsWithUsers = jobs.map((job: any) => ({
        ...job,
        owner_business_name: usersMap[job.owner_business_id]?.businessname || usersMap[job.owner_business_id]?.name || '알 수 없음',
        assigned_business_name: job.assigned_business_id ? (usersMap[job.assigned_business_id]?.businessname || usersMap[job.assigned_business_id]?.name || '알 수 없음') : null,
      }))
      
      return ok(jobsWithUsers)
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
