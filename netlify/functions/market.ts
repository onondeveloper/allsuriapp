import type { Handler, HandlerEvent, HandlerContext } from '@netlify/functions'

const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string

export const handler: Handler = async (event: HandlerEvent, context: HandlerContext) => {
  const path = event.path.replace('/.netlify/functions/market', '')
  const method = event.httpMethod

  console.log(`[market] ${method} ${path}`)

  try {
    // GET /listings
    if (method === 'GET' && path.startsWith('/listings') && !path.includes('/bids')) {
      return await handleGetListings(event)
    }

    // POST /listings/:id/claim
    if (method === 'POST' && path.match(/^\/listings\/[^/]+\/claim$/)) {
      return await handleClaimListing(event, path)
    }

    // POST /listings/:id/bid
    if (method === 'POST' && path.match(/^\/listings\/[^/]+\/bid$/)) {
      return await handleBidListing(event, path)
    }

    // GET /listings/:id/bids
    if (method === 'GET' && path.match(/^\/listings\/[^/]+\/bids$/)) {
      return await handleGetBids(event, path)
    }

    // POST /listings/:id/select-bidder
    if (method === 'POST' && path.match(/^\/listings\/[^/]+\/select-bidder$/)) {
      return await handleSelectBidder(event, path)
    }

    return {
      statusCode: 404,
      body: JSON.stringify({ message: 'Not found' })
    }
  } catch (error: any) {
    console.error('[market] error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error', error: error.message })
    }
  }
}

async function handleGetListings(event: HandlerEvent) {
  const params = event.queryStringParameters || {}
  const { status, region, category, limit, offset } = params

  let url = `${SUPABASE_URL}/rest/v1/marketplace_listings?select=*`
  
  if (status && status !== 'all') {
    url += `&status=eq.${status}`
  }
  if (region) {
    url += `&region=eq.${encodeURIComponent(region)}`
  }
  if (category) {
    url += `&category=eq.${encodeURIComponent(category)}`
  }

  url += '&order=createdat.desc'

  if (limit) {
    const l = Math.min(parseInt(limit, 10) || 50, 100)
    const o = Math.max(parseInt(offset || '0', 10), 0)
    url += `&limit=${l}&offset=${o}`
  } else {
    url += '&limit=50'
  }

  const response = await fetch(url, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    }
  })

  const data = await response.json()
  
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || [])
  }
}

async function handleClaimListing(event: HandlerEvent, path: string) {
  const id = path.split('/')[2]
  const body = JSON.parse(event.body || '{}')
  const { businessId } = body

  if (!businessId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'businessId는 필수입니다' })
    }
  }

  try {
    // RPC 호출
    const rpcResponse = await fetch(`${SUPABASE_URL}/rest/v1/rpc/claim_listing`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_listing_id: id,
        p_business_id: businessId,
      })
    })

    const rpcData = await rpcResponse.json()

    if (!rpcResponse.ok) {
      throw new Error(rpcData.message || 'RPC failed')
    }

    if (rpcData === true) {
      // 성공 - jobs_accepted_count 증가
      try {
        await fetch(`${SUPABASE_URL}/rest/v1/rpc/increment_user_jobs_accepted_count`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ user_id: businessId })
        })
      } catch (e) {
        console.warn('[market] increment count failed:', e)
      }

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ success: true })
      }
    }

    return {
      statusCode: 409,
      body: JSON.stringify({ success: false, message: '이미 다른 사업자가 가져갔습니다' })
    }
  } catch (error: any) {
    console.error('[market] claim error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: '가져가기 처리 실패', error: error.message })
    }
  }
}

async function handleBidListing(event: HandlerEvent, path: string) {
  const id = path.split('/')[2]
  const body = JSON.parse(event.body || '{}')
  const { businessId, message } = body

  if (!businessId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'businessId는 필수입니다' })
    }
  }

  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/create_order_bid`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_listing_id: id,
        p_bidder_id: businessId,
        p_message: message || null,
      })
    })

    const data = await response.json()

    if (!response.ok) {
      if (response.status === 409) {
        return {
          statusCode: 409,
          body: JSON.stringify({ success: false, message: '이미 입찰하셨습니다' })
        }
      }
      throw new Error(data.message || 'Bid failed')
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ success: true, bidId: data })
    }
  } catch (error: any) {
    console.error('[market] bid error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: '입찰 처리 실패', error: error.message })
    }
  }
}

async function handleGetBids(event: HandlerEvent, path: string) {
  const id = path.split('/')[2]

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/order_bids?listing_id=eq.${id}&select=*,bidder:users!order_bids_bidder_id_fkey(id,businessname,avatar_url,estimates_created_count,jobs_accepted_count)&order=created_at.desc`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        }
      }
    )

    const data = await response.json()

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || [])
    }
  } catch (error: any) {
    console.error('[market] get bids error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: '입찰 목록 조회 실패', error: error.message })
    }
  }
}

async function handleSelectBidder(event: HandlerEvent, path: string) {
  const id = path.split('/')[2]
  const body = JSON.parse(event.body || '{}')
  const { bidderId, ownerId } = body

  if (!bidderId || !ownerId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'bidderId, ownerId는 필수입니다' })
    }
  }

  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/select_bidder`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_listing_id: id,
        p_bidder_id: bidderId,
        p_owner_id: ownerId,
      })
    })

    const data = await response.json()

    if (!response.ok) {
      throw new Error(data.message || 'Select bidder failed')
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ success: true })
    }
  } catch (error: any) {
    console.error('[market] select bidder error:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: '입찰자 선택 실패', error: error.message })
    }
  }
}

