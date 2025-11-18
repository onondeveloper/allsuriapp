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
  const { status, region, category, limit, offset, postedBy, claimedBy, jobId } = params

  let url = `${SUPABASE_URL}/rest/v1/marketplace_listings?select=*,jobs(*)`
  
  if (status && status !== 'all') {
    url += `&status=eq.${status}`
  }
  if (region) {
    url += `&region=eq.${encodeURIComponent(region)}`
  }
  if (category) {
    url += `&category=eq.${encodeURIComponent(category)}`
  }
  if (postedBy) {
    url += `&posted_by=eq.${encodeURIComponent(postedBy)}`
  }
  if (claimedBy) {
    url += `&claimed_by=eq.${encodeURIComponent(claimedBy)}`
  }
  if (jobId) {
    url += `&jobid=eq.${encodeURIComponent(jobId)}`
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
      
      console.log(`[market] 📧 알림 전송 시작:`)
      console.log(`   - Listing: ${listing?.title}`)
      console.log(`   - 오더 소유자: ${listing?.posted_by}`)
      console.log(`   - 입찰자: ${businessId}`)

      if (listing) {
        // 1. 오더 소유자에게 알림 (새로운 입찰)
        const ownerNotificationTitle = '새로운 입찰'
        const ownerNotificationBody = `${listing.title || '오더'}에 새로운 입찰이 들어왔습니다.`
        
        console.log(`[market] 📧 오더 소유자에게 알림 생성 중...`)
        const ownerNotifResponse = await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify({
            userid: listing.posted_by,
            title: ownerNotificationTitle,
            body: ownerNotificationBody,
            type: 'new_bid',
            jobid: id, // listing ID를 jobid로 저장
            isread: false,
            createdat: new Date().toISOString(),
          })
        })
        
        if (!ownerNotifResponse.ok) {
          const errText = await ownerNotifResponse.text()
          console.warn(`[market] ❌ 오더 소유자 알림 생성 실패: ${errText}`)
        } else {
          const ownerNotifData = await ownerNotifResponse.json()
          console.log(`[market] ✅ 오더 소유자 알림 생성 완료:`, ownerNotifData)
        }
        
        // 2. 입찰자에게 알림 (입찰 확인)
        const bidderNotificationTitle = '입찰 완료'
        const bidderNotificationBody = `${listing.title || '오더'}에 입찰이 완료되었습니다. 오더 소유자의 승인을 기다리고 있어요~`
        
        console.log(`[market] 📧 입찰자에게 알림 생성 중...`)
        const bidderNotifResponse = await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify({
            userid: businessId,
            title: bidderNotificationTitle,
            body: bidderNotificationBody,
            type: 'bid_pending',
            jobid: id,
            isread: false,
            createdat: new Date().toISOString(),
          })
        })
        
        if (!bidderNotifResponse.ok) {
          const errText = await bidderNotifResponse.text()
          console.warn(`[market] ❌ 입찰자 알림 생성 실패: ${errText}`)
        } else {
          const bidderNotifData = await bidderNotifResponse.json()
          console.log(`[market] ✅ 입찰자 알림 생성 완료:`, bidderNotifData)
        }

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
        
        const selectedNotifResponse = await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify({
            userid: bidderId,
            title: selectedTitle,
            body: selectedBody,
            type: 'bid_selected',
            jobid: listing.jobid,
            isread: false,
            createdat: nowIso,
          })
        })
        
        if (!selectedNotifResponse.ok) {
          console.warn('[market] 선택 알림 생성 실패:', await selectedNotifResponse.text())
        } else {
          console.log('[market] 선택 알림 생성 완료')
        }

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
            const rejectedNotifResponse = await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
              method: 'POST',
              headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation',
              },
              body: JSON.stringify({
                userid: bid.bidder_id,
                title: rejectedTitle,
                body: rejectedBody,
                type: 'bid_rejected',
                jobid: listing.jobid,
                isread: false,
                createdat: nowIso,
              })
            })
            
            if (!rejectedNotifResponse.ok) {
              console.warn('[market] 거절 알림 생성 실패:', await rejectedNotifResponse.text())
            }

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
        
        // 채팅방 생성 (오더 소유자와 선택된 입찰자 간)
        try {
          const ownerResponse = await fetch(
            `${SUPABASE_URL}/rest/v1/marketplace_listings?id=eq.${id}&select=posted_by`,
            {
              headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              }
            }
          )
          const ownerData = await ownerResponse.json()
          const owner = Array.isArray(ownerData) && ownerData.length > 0 ? ownerData[0] : null
          
          if (owner && owner.posted_by) {
            const roomId = `order_${id}`
            console.log('[market] 채팅방 생성 중:', { roomId, owner: owner.posted_by, bidder: bidderId })
            
            // 채팅방 생성 (upsert)
            const chatRoomResponse = await fetch(`${SUPABASE_URL}/rest/v1/chat_rooms`, {
              method: 'POST',
              headers: {
                apikey: SUPABASE_SERVICE_ROLE_KEY,
                Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                'Content-Type': 'application/json',
                'Prefer': 'resolution=merge-duplicates',
              },
              body: JSON.stringify({
                id: roomId,
                listingid: id,
                jobid: listing.jobid,
                participant_a: owner.posted_by,
                participant_b: bidderId,
                createdat: nowIso,
                updatedat: nowIso,
                active: true,
              })
            })
            
            if (!chatRoomResponse.ok) {
              console.warn('[market] 채팅방 생성 실패:', await chatRoomResponse.text())
            } else {
              console.log('[market] 채팅방 생성 완료:', roomId)
              
              // 시스템 메시지 추가
              const messageResponse = await fetch(`${SUPABASE_URL}/rest/v1/chat_messages`, {
                method: 'POST',
                headers: {
                  apikey: SUPABASE_SERVICE_ROLE_KEY,
                  Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  room_id: roomId,
                  sender_id: owner.posted_by,
                  content: '안녕하세요, 오더 관련 채팅방입니다',
                  type: 'system',
                  createdat: nowIso,
                })
              })
              
              if (!messageResponse.ok) {
                console.warn('[market] 시스템 메시지 생성 실패:', await messageResponse.text())
              } else {
                console.log('[market] 시스템 메시지 생성 완료')
              }
            }
          }
        } catch (chatErr: any) {
          console.warn('[market] 채팅방 생성 실패 (무시):', chatErr.message)
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

