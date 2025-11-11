import type { Handler, HandlerEvent, HandlerContext } from '@netlify/functions'

const SUPABASE_URL = process.env.SUPABASE_URL as string
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY as string

export const handler: Handler = async (event: HandlerEvent, context: HandlerContext) => {
  // Netlify redirects: /api/market/* -> /.netlify/functions/market/*
  // event.path will be like: /api/market/listings/xxx/claim
  let path = event.path
  
  // Remove /api/market prefix
  if (path.startsWith('/api/market')) {
    path = path.replace('/api/market', '')
  } else if (path.startsWith('/.netlify/functions/market')) {
    path = path.replace('/.netlify/functions/market', '')
  }
  
  const method = event.httpMethod

  console.log(`[market] ${method} ${event.path} -> ${path}`)

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

    // 알림 및 푸시 알림 전송
    try {
      const listingResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${id}&select=title,posted_by`,
        {
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          }
        }
      )
      const listings = await listingResponse.json()
      const listing = Array.isArray(listings) && listings.length > 0 ? listings[0] : null

      if (listing) {
        const notificationTitle = '새로운 입찰'
        const notificationBody = `${listing.title || '오더'}에 새로운 입찰이 들어왔습니다.`
        
        // DB 알림 생성
        await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userid: listing.posted_by,
            title: notificationTitle,
            body: notificationBody,
            type: 'new_bid',
            jobId: id,
            isread: false,
            createdat: new Date().toISOString(),
          })
        })

        // 푸시 알림 전송 (Supabase Edge Function)
        try {
          await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              userId: listing.posted_by,
              title: notificationTitle,
              body: notificationBody,
              data: {
                type: 'new_bid',
                listingId: id,
              },
            }),
          })
          console.log('✅ [market] 푸시 알림 전송 완료')
        } catch (pushErr: any) {
          console.warn('[market] 푸시 알림 전송 실패 (무시):', pushErr.message)
        }
      }
    } catch (e: any) {
      console.warn('[market] notification failed:', e.message)
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

  console.log(`[handleSelectBidder] 시작:`, { id, bidderId, ownerId })

  if (!bidderId || !ownerId) {
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'bidderId, ownerId는 필수입니다' })
    }
  }

  try {
    console.log(`[handleSelectBidder] RPC 호출 중...`)
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
    console.log(`[handleSelectBidder] RPC 응답:`, { status: response.status, data })

    if (!response.ok) {
      console.error(`[handleSelectBidder] RPC 실패:`, data)
      throw new Error(data.message || data.hint || data.details || 'Select bidder failed')
    }

    // 알림 및 푸시 알림 전송
    try {
      // 오더 정보 조회
      const listingResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${id}&select=title,jobid`,
        {
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          }
        }
      )
      const listings = await listingResponse.json()
      const listing = Array.isArray(listings) && listings.length > 0 ? listings[0] : null

      if (listing) {
        const nowIso = new Date().toISOString()

        // 선택된 입찰자에게 알림
        const selectedTitle = '오더 선택됨'
        const selectedBody = `${listing.title || '오더'}에 선택되었습니다!`
        
        await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userid: bidderId,
            title: selectedTitle,
            body: selectedBody,
            type: 'bid_selected',
            jobId: listing.jobid,
            isread: false,
            createdat: nowIso,
          })
        })

        // 선택된 사업자에게 푸시 알림
        try {
          await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              userId: bidderId,
              title: selectedTitle,
              body: selectedBody,
              data: { type: 'bid_selected', listingId: id },
            }),
          })
        } catch (pushErr: any) {
          console.warn('[market] 푸시 알림 실패:', pushErr.message)
        }

        // 거절된 입찰자들에게 알림
        const rejectedResponse = await fetch(
          `${SUPABASE_URL}/rest/v1/order_bids?listing_id=eq.${id}&status=eq.rejected&select=bidder_id`,
          {
            headers: {
              apikey: SUPABASE_SERVICE_ROLE_KEY,
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            }
          }
        )
        const rejectedBids = await rejectedResponse.json()

        if (Array.isArray(rejectedBids) && rejectedBids.length > 0) {
          const rejectedTitle = '오더가 다른 사업자에게 이관되었습니다'
          const rejectedBody = `${listing.title || '오더'}가 다른 사업자에게 이관되었습니다. 다음 기회를 노려보시기 바랍니다.`
          
          // 각 거절된 입찰자에게 알림
          for (const bid of rejectedBids) {
            // DB 알림
            await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
              method: 'POST',
              headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                userid: bid.bidder_id,
                title: rejectedTitle,
                body: rejectedBody,
                type: 'bid_rejected',
                jobId: listing.jobid,
                isread: false,
                createdat: nowIso,
              })
            })

            // 푸시 알림
            try {
              await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
                method: 'POST',
                headers: {
                  Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  userId: bid.bidder_id,
                  title: rejectedTitle,
                  body: rejectedBody,
                  data: { type: 'bid_rejected', listingId: id },
                }),
              })
            } catch (pushErr: any) {
              console.warn('[market] 푸시 알림 실패:', pushErr.message)
            }
          }
        }
      }
    } catch (e: any) {
      console.warn('[market] notification/push failed:', e.message)
    }

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ success: true })
    }
  } catch (error: any) {
    console.error('[handleSelectBidder] 에러:', error)
    return {
      statusCode: 500,
      body: JSON.stringify({ 
        success: false,
        message: error.message || '입찰자 선택 실패',
        error: error.message 
      })
    }
  }
}

