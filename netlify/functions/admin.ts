/// <reference types="node" />
// Netlify function: admin API router
// Proxies selected endpoints used by backend/public/admin.js
// import { createClient } from "@supabase/supabase-js"; // ✅ 제거

const ADMIN_TOKEN = process.env.ADMIN_TOKEN || process.env.ADMIN_DEVELOPER_TOKEN || 'devtoken'
const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string

function unauthorized() {
  return { statusCode: 401, body: JSON.stringify({ message: '관리자 권한이 필요합니다' }), headers: { 'Content-Type': 'application/json' } };
}

function withAuth(headers: Record<string, string>): boolean {
  const token = headers['admin-token'] || headers['x-admin-token'] || ''
  return token === ADMIN_TOKEN
}

export const handler = async (event: any) => { // event 타입 any로 임시 설정
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
      const listingsRes = await fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?select=id,status,claimed_by,budget_amount`, { headers })
      const listings = await listingsRes.json()
      console.log('[ADMIN DASHBOARD] Listings count:', Array.isArray(listings) ? listings.length : 0)
      console.log('[ADMIN DASHBOARD] Listings sample:', Array.isArray(listings) ? listings.slice(0, 3) : [])

      const totalOrders = Array.isArray(listings) ? listings.length : 0
      // 입찰 중: status가 'created' 또는 'open'이고 아직 claimed_by가 없는 경우
      const pendingOrders = Array.isArray(listings)
        ? listings.filter((l: any) => (l.status === 'created' || l.status === 'open') && !l.claimed_by).length
        : 0
      // 완료: status가 'assigned'이거나 claimed_by가 있는 경우
      const completedOrdersList = Array.isArray(listings)
        ? listings.filter((l: any) => l.status === 'assigned' || l.claimed_by)
        : []
      const completedOrders = completedOrdersList.length

      // 완료된 오더의 총 예산 금액
      const totalOrderAmount = completedOrdersList.reduce((sum: number, l: any) => {
        const budget = l.budget_amount || 0
        console.log(`[ADMIN DASHBOARD] Order budget: ${budget}, status: ${l.status}`)
        return sum + budget
      }, 0)

      console.log('[ADMIN DASHBOARD] Orders - Total:', totalOrders, 'Pending:', pendingOrders, 'Completed:', completedOrders)
      console.log('[ADMIN DASHBOARD] Total order amount:', totalOrderAmount)

      // Fetch jobs (기존 jobs 테이블)
      const jobsRes = await fetch(`${SUPABASE_URL}/rest/v1/jobs?select=id,status`, { headers })
      const jobs = await jobsRes.json()
      const totalJobs = Array.isArray(jobs) ? jobs.length : 0
      const pendingJobs = Array.isArray(jobs) ? jobs.filter((j: any) => j.status === 'pending').length : 0
      const completedJobs = Array.isArray(jobs) ? jobs.filter((j: any) => j.status === 'completed').length : 0

      return {
        statusCode: 200,
        body: JSON.stringify({
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
          totalOrderAmount: Math.round(totalOrderAmount),
          totalJobs,
          pendingJobs,
          completedJobs
        }),
        headers: { 'Content-Type': 'application/json' }
      };
    }

    // Admin me
    if (event.httpMethod === 'GET' && path === '/me') {
      return { statusCode: 200, body: JSON.stringify({ role: 'developer', permissions: { canManageUsers: true, canManageAds: true } }), headers: { 'Content-Type': 'application/json' } };
    }

    // Users list (from Supabase)
    if (event.httpMethod === 'GET' && path === '/users') {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/users?select=*`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const json = await res.json()
      return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } };
    }

    // Users search
    if (event.httpMethod === 'GET' && path.startsWith('/users/search')) {
      const q = new URLSearchParams(event.queryStringParameters as any).get('q') || ''
      const like = encodeURIComponent(`%${q}%`)
      const url = `${SUPABASE_URL}/rest/v1/users?or=(name.ilike.${like},email.ilike.${like})`
      const res = await fetch(url, { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
      const json = await res.json()
      return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } };
    }

    // User admin toggle (관리자 권한 지정/해제)
    if (event.httpMethod === 'PATCH' && path.startsWith('/users/') && path.endsWith('/admin')) {
      const userId = path.split('/')[2]
      const body = JSON.parse(event.body || '{}')
      const is_admin = body.is_admin === true

      const upRes = await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`, {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: JSON.stringify({ is_admin }),
      })

      if (!upRes.ok) {
        const errText = await upRes.text()
        console.error('❌ 관리자 권한 변경 실패:', upRes.status, errText)
        return { statusCode: 500, body: JSON.stringify({ success: false, message: '관리자 권한 변경 실패', error: errText }), headers: { 'Content-Type': 'application/json' } };
      }

      const updated = await upRes.json()
      const user = Array.isArray(updated) ? updated[0] : updated
      console.log('✅ 관리자 권한 변경 성공:', userId, '→', is_admin)
      return { 
        statusCode: 200, 
        body: JSON.stringify({ 
          success: true, 
          message: is_admin ? '관리자로 지정되었습니다' : '관리자 권한이 해제되었습니다',
          data: user 
        }), 
        headers: { 'Content-Type': 'application/json' } 
      };
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
        return { statusCode: 500, body: JSON.stringify({ message: '상태 업데이트 실패', error: errText }), headers: { 'Content-Type': 'application/json' } };
      }

      const updated = await upRes.json()
      console.log('✅ 사용자 상태 업데이트 성공:', userId, '→', status)
      return { statusCode: 200, body: JSON.stringify({ success: true, user: Array.isArray(updated) ? updated[0] : updated }), headers: { 'Content-Type': 'application/json' } };
    }

    // DELETE user (CASCADE 삭제 사용)
    if (event.httpMethod === 'DELETE' && path.startsWith('/users/')) {
      const userId = path.split('/')[2]
      
      console.log(`[ADMIN] 사용자 삭제 시작: userId=${userId}`)
      
      // RPC 함수 호출로 CASCADE 삭제
      const rpcRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/delete_user_cascade`, {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ user_id_to_delete: userId }),
      })
      
      if (!rpcRes.ok) {
        const errText = await rpcRes.text()
        console.error('❌ 사용자 삭제 실패:', rpcRes.status, errText)
        return { 
          statusCode: 500, 
          body: JSON.stringify({ success: false, message: '사용자 삭제 실패', error: errText }), 
          headers: { 'Content-Type': 'application/json' } 
        };
      }
      
      const deleted_counts = await rpcRes.json()
      console.log(`[ADMIN] 사용자 삭제 완료:`, deleted_counts)
      
      return { 
        statusCode: 200, 
        body: JSON.stringify({ 
          success: true, 
          message: '사용자가 삭제되었습니다',
          deleted_counts 
        }), 
        headers: { 'Content-Type': 'application/json' } 
      };
    }

    // DELETE listing (오더 삭제)
    if (event.httpMethod === 'DELETE' && path.startsWith('/listings/')) {
      const listingId = path.split('/')[2]
      
      console.log(`[ADMIN] 오더 삭제 시작: listingId=${listingId}`)
      
      // marketplace_listings 삭제 (CASCADE로 order_bids도 삭제됨)
      const delRes = await fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${encodeURIComponent(listingId)}`, {
        method: 'DELETE',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      })
      
      if (!delRes.ok) {
        const errText = await delRes.text()
        console.error('❌ 오더 삭제 실패:', delRes.status, errText)
        return { 
          statusCode: 500, 
          body: JSON.stringify({ success: false, message: '오더 삭제 실패', error: errText }), 
          headers: { 'Content-Type': 'application/json' } 
        };
      }
      
      console.log(`[ADMIN] 오더 삭제 완료: ${listingId}`)
      
      return { 
        statusCode: 200, 
        body: JSON.stringify({ 
          success: true, 
          message: '오더가 삭제되었습니다'
        }), 
        headers: { 'Content-Type': 'application/json' } 
      };
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
      return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } };
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
      if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '견적 상태 업데이트 실패' }), headers: { 'Content-Type': 'application/json' } };
      return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } };
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
        return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } };
      }
    }

    // Call 공사 목록 (jobs 테이블)
    if (event.httpMethod === 'GET' && path === '/calls') {
      const jobsRes = await fetch(`${SUPABASE_URL}/rest/v1/jobs?select=*&order=created_at.desc`, {
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
      })
      const jobs = await jobsRes.json()

      if (!Array.isArray(jobs)) {
        return { statusCode: 200, body: JSON.stringify([]), headers: { 'Content-Type': 'application/json' } };
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

      return { statusCode: 200, body: JSON.stringify(jobsWithUsers), headers: { 'Content-Type': 'application/json' } };
    }

    // Ads endpoints via Supabase
    if (path.startsWith('/ads')) {
      const sub = path.replace(/^\/ads/, '')
      if (event.httpMethod === 'GET' && (sub === '' || sub === '/')) {
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?select=*`, { headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` } })
        const json = await res.json()
        return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } };
      }
      if (event.httpMethod === 'POST' && (sub === '' || sub === '/')) {
        const payload = JSON.parse(event.body || '{}')
        payload.createdat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads`, {
          method: 'POST',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 생성 실패' }), headers: { 'Content-Type': 'application/json' } };
        return { statusCode: 200, body: JSON.stringify(await res.json()), headers: { 'Content-Type': 'application/json' } };
      }
      if (event.httpMethod === 'PUT' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const payload = JSON.parse(event.body || '{}')
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
          body: JSON.stringify(payload),
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 업데이트 실패' }), headers: { 'Content-Type': 'application/json' } };
        return { statusCode: 200, body: JSON.stringify(await res.json()), headers: { 'Content-Type': 'application/json' } };
      }
      if (event.httpMethod === 'DELETE' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
        })
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '광고 삭제 실패' }), headers: { 'Content-Type': 'application/json' } };
        return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } };
      }
    }

    return { statusCode: 404, body: JSON.stringify({ message: 'Not Found' }), headers: { 'Content-Type': 'application/json' } };
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ message: 'Admin function error', error: String(e) }), headers: { 'Content-Type': 'application/json' } };
  }
}
