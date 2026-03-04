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

      // Fetch users (Supabase 에러 객체 반환 시 빈 배열로 처리)
      const usersRes = await fetch(`${SUPABASE_URL}/rest/v1/users?select=role,businessstatus`, { headers })
      const usersRaw = await usersRes.json()
      const users = Array.isArray(usersRaw) ? usersRaw : (usersRaw?.code ? [] : [])
      const totalBusinessUsers = Array.isArray(users) ? users.filter((u: any) => u.role === 'business').length : 0
      const totalCustomers = Array.isArray(users) ? users.filter((u: any) => u.role === 'customer').length : 0
      const pendingBusinessUsers = Array.isArray(users) ? users.filter((u: any) => u.role === 'business' && u.businessstatus === 'pending').length : 0

      // Fetch estimates (에러 객체 시 빈 배열)
      const estimatesRes = await fetch(`${SUPABASE_URL}/rest/v1/estimates?select=status,amount`, { headers })
      const estimatesRaw = await estimatesRes.json()
      const estimates = Array.isArray(estimatesRaw) ? estimatesRaw : (estimatesRaw?.code ? [] : [])

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

      // Fetch marketplace_listings (에러 객체 시 빈 배열)
      const listingsRes = await fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?select=id,status,claimed_by,budget_amount`, { headers })
      const listingsRaw = await listingsRes.json()
      const listings = Array.isArray(listingsRaw) ? listingsRaw : (listingsRaw?.code ? [] : [])
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

      // Fetch jobs (에러 객체 시 빈 배열)
      const jobsRes = await fetch(`${SUPABASE_URL}/rest/v1/jobs?select=id,status`, { headers })
      const jobsRaw = await jobsRes.json()
      const jobs = Array.isArray(jobsRaw) ? jobsRaw : (jobsRaw?.code ? [] : [])
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

    // ─── 헬퍼: Supabase 배치 유저 조회 ─────────────────────────────────
    const sbHeaders = { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` }
    const fetchUsers = async (ids: string[]): Promise<Record<string, any>> => {
      const validIds = ids.filter(Boolean).map(String)
      if (!validIds.length) return {}
      const idList = validIds.map(id => `"${id}"`).join(',')
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/users?select=id,name,businessname,phonenumber,role&id=in.(${idList})`,
        { headers: sbHeaders }
      )
      const users = await res.json()
      if (!Array.isArray(users) || (users as any)?.code) return {}
      const map: Record<string, any> = {}
      for (const u of users) {
        const key = u?.id != null ? String(u.id) : null
        if (key) map[key] = u
      }
      return map
    }
    const getUserName = (map: Record<string, any>, id: string | null | undefined) => {
      if (!id) return '알 수 없음'
      const u = map[String(id)] || map[id]
      return u ? (u.businessname || u.name || '알 수 없음') : '알 수 없음'
    }

    // Call 오더 목록 (marketplace_listings 테이블)
    if (event.httpMethod === 'GET' && path === '/calls') {
      const listRes = await fetch(
        `${SUPABASE_URL}/rest/v1/marketplace_listings?select=id,title,description,posted_by,claimed_by,claimed_at,budget_amount,status,region,category,createdat,updatedat,media_urls,bid_count&order=createdat.desc&limit=200`,
        { headers: sbHeaders }
      )
      const listings = await listRes.json()
      if (!Array.isArray(listings)) {
        return { statusCode: 200, body: JSON.stringify([]), headers: { 'Content-Type': 'application/json' } }
      }
      const allIds = [...new Set([...listings.map((l: any) => l.posted_by), ...listings.map((l: any) => l.claimed_by)].filter(Boolean))] as string[]
      const usersMap = await fetchUsers(allIds)
      const result = listings.map((l: any) => ({
        ...l,
        owner_business_name: getUserName(usersMap, l.posted_by),
        assigned_business_name: l.claimed_by ? getUserName(usersMap, l.claimed_by) : null,
        created_at: l.createdat,
        updated_at: l.updatedat,
        location: l.region,
      }))
      return { statusCode: 200, body: JSON.stringify(result), headers: { 'Content-Type': 'application/json' } }
    }

    // 오더 프로세스 상세 (낙찰→진행→완료→후기)
    if (event.httpMethod === 'GET' && /^\/listings\/[^/]+\/process$/.test(path)) {
      const listingId = path.split('/')[2]
      const [listingRes, reviewsRes] = await Promise.all([
        fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${listingId}&select=*&limit=1`, { headers: sbHeaders }),
        fetch(`${SUPABASE_URL}/rest/v1/order_reviews?listing_id=eq.${listingId}&select=id,reviewer_id,reviewee_id,rating,tags,comment,created_at&order=created_at.desc`, { headers: sbHeaders }),
      ])
      const [listingArr, reviews] = await Promise.all([listingRes.json(), reviewsRes.json()])
      const listing = Array.isArray(listingArr) ? listingArr[0] : null
      if (!listing) return { statusCode: 404, body: JSON.stringify({ message: '오더를 찾을 수 없습니다' }), headers: { 'Content-Type': 'application/json' } }

      const jobid = listing.jobid ?? listing.jobId
      // 입찰 조회: listing_id=listingId OR job_id=jobid OR listing_id=jobid (한 번에 or 쿼리로 조회)
      const orParts = [`listing_id.eq.${listingId}`]
      if (jobid) {
        orParts.push(`job_id.eq.${jobid}`, `listing_id.eq.${jobid}`)
      }
      const orFilter = encodeURIComponent(`or(${orParts.join(',')})`)
      const bidsRes = await fetch(
        `${SUPABASE_URL}/rest/v1/order_bids?${orFilter}&select=id,bidder_id,bid_amount,message,status,created_at&order=created_at.asc`,
        { headers: sbHeaders }
      )
      const bidsRaw = await bidsRes.json()
      const bids = Array.isArray(bidsRaw) && !(bidsRaw as any)?.code ? bidsRaw : []

      const userIds = [...new Set([
        listing.posted_by, listing.claimed_by,
        ...(Array.isArray(bids) ? bids.map((b: any) => b.bidder_id) : []),
        ...(Array.isArray(reviews) ? reviews.flatMap((r: any) => [r.reviewer_id, r.reviewee_id]) : []),
      ].filter(Boolean))] as string[]
      const usersMap = await fetchUsers(userIds)

      const winnerBid = Array.isArray(bids) && listing.claimed_by
        ? bids.find((b: any) => b.bidder_id === listing.claimed_by) || null
        : null

      return {
        statusCode: 200,
        body: JSON.stringify({
          listing: {
            ...listing,
            owner_name: getUserName(usersMap, listing.posted_by),
            winner_name: listing.claimed_by ? getUserName(usersMap, listing.claimed_by) : null,
            owner_phone: usersMap[listing.posted_by]?.phonenumber || null,
            winner_phone: listing.claimed_by ? (usersMap[listing.claimed_by]?.phonenumber || null) : null,
          },
          bids: Array.isArray(bids) ? bids.map((b: any) => ({ ...b, bidder_name: getUserName(usersMap, b.bidder_id), is_winner: b.bidder_id === listing.claimed_by })) : [],
          winner_bid: winnerBid,
          reviews: Array.isArray(reviews) ? reviews.map((r: any) => ({ ...r, reviewer_name: getUserName(usersMap, r.reviewer_id), reviewee_name: getUserName(usersMap, r.reviewee_id) })) : [],
        }),
        headers: { 'Content-Type': 'application/json' }
      }
    }

    // 오더 상태 변경
    if (event.httpMethod === 'PATCH' && /^\/listings\/[^/]+\/status$/.test(path)) {
      const listingId = path.split('/')[2]
      const body = JSON.parse(event.body || '{}')
      const res = await fetch(`${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${listingId}`, {
        method: 'PATCH',
        headers: { ...sbHeaders, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify({ status: body.status, updatedat: new Date().toISOString() }),
      })
      const resText = await res.text()
      if (!res.ok) return { statusCode: 500, body: JSON.stringify({ success: false, error: resText }), headers: { 'Content-Type': 'application/json' } }
      return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } }
    }

    // 게시물 목록 (community_posts)
    if (event.httpMethod === 'GET' && path === '/posts') {
      const res = await fetch(
        `${SUPABASE_URL}/rest/v1/community_posts?select=id,title,content,author_id,created_at,updated_at,likes_count,comments_count,is_active,category&order=created_at.desc&limit=200`,
        { headers: sbHeaders }
      )
      const posts = await res.json()
      if (!Array.isArray(posts)) return { statusCode: 200, body: JSON.stringify([]), headers: { 'Content-Type': 'application/json' } }
      const authorIds = [...new Set(posts.map((p: any) => p.author_id).filter(Boolean))] as string[]
      const usersMap = await fetchUsers(authorIds)
      const result = posts.map((p: any) => ({
        ...p,
        author_name: getUserName(usersMap, p.author_id),
        author_role: usersMap[p.author_id]?.role || 'unknown',
      }))
      return { statusCode: 200, body: JSON.stringify(result), headers: { 'Content-Type': 'application/json' } }
    }

    // 게시물 삭제
    if (event.httpMethod === 'DELETE' && /^\/posts\/[^/]+$/.test(path)) {
      const postId = path.split('/')[2]
      const res = await fetch(`${SUPABASE_URL}/rest/v1/community_posts?id=eq.${postId}`, {
        method: 'DELETE',
        headers: sbHeaders,
      })
      if (!res.ok) {
        const errText = await res.text()
        return { statusCode: 500, body: JSON.stringify({ success: false, error: errText }), headers: { 'Content-Type': 'application/json' } }
      }
      return { statusCode: 200, body: JSON.stringify({ success: true, message: '게시글이 삭제되었습니다' }), headers: { 'Content-Type': 'application/json' } }
    }

    // 채팅방 목록 (createdat/created_at 스키마 호환)
    if (event.httpMethod === 'GET' && path === '/chats') {
      const selectCols = 'id,participant_a,participant_b,status'
      let rooms: any[] = []
      for (const orderCol of ['createdat', 'created_at']) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/chat_rooms?select=${selectCols},${orderCol}&order=${orderCol}.desc&limit=200`,
          { headers: sbHeaders }
        )
        const data = await res.json()
        if (Array.isArray(data) && !(data as any)?.code) {
          rooms = data
          break
        }
      }
      const pIds = [...new Set(rooms.flatMap((r: any) => [r.participant_a, r.participant_b]).filter(Boolean))] as string[]
      const usersMap = await fetchUsers(pIds)
      const result = rooms.map((r: any) => ({
        ...r,
        participant_a_name: getUserName(usersMap, r.participant_a),
        participant_b_name: getUserName(usersMap, r.participant_b),
        participant_a_role: usersMap[String(r.participant_a)]?.role || 'unknown',
        participant_b_role: usersMap[String(r.participant_b)]?.role || 'unknown',
      }))
      return { statusCode: 200, body: JSON.stringify(result), headers: { 'Content-Type': 'application/json' } }
    }

    // 채팅방 메시지 (createdat/created_at 스키마 호환)
    if (event.httpMethod === 'GET' && /^\/chats\/[^/]+\/messages$/.test(path)) {
      const roomId = path.split('/')[2]
      let messages: any[] = []
      for (const orderCol of ['created_at', 'createdat']) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/chat_messages?room_id=eq.${roomId}&select=id,sender_id,content,image_url,video_url,${orderCol},message_type&order=${orderCol}.asc&limit=100`,
          { headers: sbHeaders }
        )
        const data = await res.json()
        if (Array.isArray(data) && !(data as any)?.code) {
          messages = data
          break
        }
      }
      const senderIds = [...new Set(messages.map((m: any) => m.sender_id).filter(Boolean))] as string[]
      const usersMap = await fetchUsers(senderIds)
      const result = messages.map((m: any) => ({ ...m, sender_name: getUserName(usersMap, m.sender_id) }))
      return { statusCode: 200, body: JSON.stringify(result), headers: { 'Content-Type': 'application/json' } }
    }

    // 채팅방 삭제
    if (event.httpMethod === 'DELETE' && /^\/chats\/[^/]+$/.test(path)) {
      const roomId = path.split('/')[2]
      // 메시지 먼저 삭제
      await fetch(`${SUPABASE_URL}/rest/v1/chat_messages?room_id=eq.${roomId}`, { method: 'DELETE', headers: sbHeaders })
      // 채팅방 삭제
      const res = await fetch(`${SUPABASE_URL}/rest/v1/chat_rooms?id=eq.${roomId}`, { method: 'DELETE', headers: sbHeaders })
      if (!res.ok) {
        const errText = await res.text()
        return { statusCode: 500, body: JSON.stringify({ success: false, error: errText }), headers: { 'Content-Type': 'application/json' } }
      }
      return { statusCode: 200, body: JSON.stringify({ success: true, message: '채팅방이 삭제되었습니다' }), headers: { 'Content-Type': 'application/json' } }
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
        payload.updatedat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            Prefer: 'return=representation',  // Supabase가 생성된 row를 JSON으로 반환하도록 요청
          },
          body: JSON.stringify(payload),
        })
        const resText = await res.text()
        if (!res.ok) {
          console.error('[ads POST] Supabase error:', res.status, resText)
          return { statusCode: 500, body: JSON.stringify({ message: '광고 생성 실패', error: resText }), headers: { 'Content-Type': 'application/json' } };
        }
        // 빈 응답 방어 처리
        const created = resText ? JSON.parse(resText) : []
        return { statusCode: 201, body: JSON.stringify(Array.isArray(created) ? (created[0] ?? {}) : created), headers: { 'Content-Type': 'application/json' } };
      }
      if (event.httpMethod === 'PUT' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const payload = JSON.parse(event.body || '{}')
        payload.updatedat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            Prefer: 'return=representation',
          },
          body: JSON.stringify(payload),
        })
        const resText = await res.text()
        if (!res.ok) {
          console.error('[ads PUT] Supabase error:', res.status, resText)
          return { statusCode: 500, body: JSON.stringify({ message: '광고 업데이트 실패', error: resText }), headers: { 'Content-Type': 'application/json' } };
        }
        const updated = resText ? JSON.parse(resText) : []
        return { statusCode: 200, body: JSON.stringify(Array.isArray(updated) ? (updated[0] ?? {}) : updated), headers: { 'Content-Type': 'application/json' } };
      }
      if (event.httpMethod === 'DELETE' && /^\/(.+)/.test(sub)) {
        const id = sub.slice(1)
        const res = await fetch(`${SUPABASE_URL}/rest/v1/ads?id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
          headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` },
        })
        if (!res.ok) {
          const errText = await res.text()
          console.error('[ads DELETE] Supabase error:', res.status, errText)
          return { statusCode: 500, body: JSON.stringify({ message: '광고 삭제 실패', error: errText }), headers: { 'Content-Type': 'application/json' } };
        }
        return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } };
      }
    }

    // ─── 공지 배너 CRUD ─────────────────────────────────────────────────
    if (path.startsWith('/announcements')) {
      const sub = path.replace(/^\/announcements/, '')

      // 전체 조회 (관리자)
      if (event.httpMethod === 'GET' && (sub === '' || sub === '/')) {
        const res = await fetch(
          `${SUPABASE_URL}/rest/v1/announcements?select=*&order=sort_order.asc,createdat.desc`,
          { headers: sbHeaders }
        )
        const json = await res.json()
        return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } }
      }

      // 앱용 활성 공지 조회 (현재 시간 기준 유효한 것만)
      if (event.httpMethod === 'GET' && sub === '/active') {
        const now = new Date().toISOString()
        const url = `${SUPABASE_URL}/rest/v1/announcements?is_active=eq.true&or=(start_at.is.null,start_at.lte.${now})&or=(end_at.is.null,end_at.gte.${now})&order=sort_order.asc&limit=5`
        const res = await fetch(url, { headers: sbHeaders })
        const json = await res.json()
        return { statusCode: 200, body: JSON.stringify(Array.isArray(json) ? json : []), headers: { 'Content-Type': 'application/json' } }
      }

      // 생성
      if (event.httpMethod === 'POST' && (sub === '' || sub === '/')) {
        const payload = JSON.parse(event.body || '{}')
        payload.createdat = new Date().toISOString()
        payload.updatedat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/announcements`, {
          method: 'POST',
          headers: { ...sbHeaders, 'Content-Type': 'application/json', Prefer: 'return=representation' },
          body: JSON.stringify(payload),
        })
        const resText = await res.text()
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '공지 생성 실패', error: resText }), headers: { 'Content-Type': 'application/json' } }
        const created = resText ? JSON.parse(resText) : []
        return { statusCode: 201, body: JSON.stringify(Array.isArray(created) ? (created[0] ?? {}) : created), headers: { 'Content-Type': 'application/json' } }
      }

      // 수정
      if (event.httpMethod === 'PUT' && /^\/[^/]+$/.test(sub)) {
        const id = sub.slice(1)
        const payload = JSON.parse(event.body || '{}')
        payload.updatedat = new Date().toISOString()
        const res = await fetch(`${SUPABASE_URL}/rest/v1/announcements?id=eq.${id}`, {
          method: 'PATCH',
          headers: { ...sbHeaders, 'Content-Type': 'application/json', Prefer: 'return=representation' },
          body: JSON.stringify(payload),
        })
        const resText = await res.text()
        if (!res.ok) return { statusCode: 500, body: JSON.stringify({ message: '공지 수정 실패', error: resText }), headers: { 'Content-Type': 'application/json' } }
        return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } }
      }

      // 삭제
      if (event.httpMethod === 'DELETE' && /^\/[^/]+$/.test(sub)) {
        const id = sub.slice(1)
        const res = await fetch(`${SUPABASE_URL}/rest/v1/announcements?id=eq.${id}`, {
          method: 'DELETE',
          headers: sbHeaders,
        })
        if (!res.ok) {
          const errText = await res.text()
          return { statusCode: 500, body: JSON.stringify({ message: '공지 삭제 실패', error: errText }), headers: { 'Content-Type': 'application/json' } }
        }
        return { statusCode: 200, body: JSON.stringify({ success: true }), headers: { 'Content-Type': 'application/json' } }
      }
    }

    return { statusCode: 404, body: JSON.stringify({ message: 'Not Found' }), headers: { 'Content-Type': 'application/json' } };
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ message: 'Admin function error', error: String(e) }), headers: { 'Content-Type': 'application/json' } };
  }
}
