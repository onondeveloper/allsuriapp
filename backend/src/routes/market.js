const express = require('express');
const router = express.Router();
const { supabase } = require('../config/supabase');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;

// GET /api/market/listings
// Query params: status, region, category, limit, offset
router.get('/listings', async (req, res) => {
  try {
    const { status, region, category, limit, offset } = req.query;
    let qb = supabase.from('marketplace_listings').select('*');

    if (status && status !== 'all') qb = qb.eq('status', status);
    if (region) qb = qb.eq('region', region);
    if (category) qb = qb.eq('category', category);

    let rangeStart = 0;
    let rangeEnd = 49;
    if (limit) {
      const l = Math.min(parseInt(limit, 10) || 50, 100);
      const o = Math.max(parseInt(offset, 10) || 0, 0);
      rangeStart = o;
      rangeEnd = o + l - 1;
    }

    const { data, error } = await qb.order('createdat', { ascending: false }).range(rangeStart, rangeEnd);
    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[market] list error:', error);
    res.status(500).json({ message: 'CAll 목록 조회 실패' });
  }
});

// POST /api/market/listings
// Body: { jobId, title, description?, region?, category?, budgetAmount?, postedBy, expiresAt? }
router.post('/listings', async (req, res) => {
  try {
    const {
      jobId,
      title,
      description,
      region,
      category,
      budgetAmount,
      postedBy,
      expiresAt,
    } = req.body || {};

    if (!jobId || !title || !postedBy) {
      return res.status(400).json({ message: 'jobId, title, postedBy는 필수입니다' });
    }

    const payload = {
      jobid: jobId,
      title,
      description: description || null,
      region: region || null,
      category: category || null,
      budget_amount: typeof budgetAmount === 'number' ? budgetAmount : null,
      posted_by: postedBy,
      status: 'open',
      expires_at: expiresAt || null,
      createdat: new Date().toISOString(),
      updatedat: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from('marketplace_listings')
      .insert([payload])
      .select()
      .maybeSingle();
    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[market] create listing error:', error);
    res.status(500).json({ message: '마켓플레이스 등록 실패' });
  }
});

// POST /api/market/listings/:id/bid
// Body: { businessId, message? }
// 새로운 입찰 시스템: 여러 사업자가 입찰 가능
router.post('/listings/:id/bid', async (req, res) => {
  try {
    const { id } = req.params;
    const { businessId, message } = req.body || {};
    if (!businessId) return res.status(400).json({ message: 'businessId는 필수입니다' });

    // RPC 호출: create_order_bid
    const { data, error } = await supabase.rpc('create_order_bid', {
      p_listing_id: id,
      p_bidder_id: businessId,
      p_message: message || null,
    });

    if (error) {
      if (error.code === '23505') { // unique violation
        return res.status(409).json({ success: false, message: '이미 입찰하셨습니다' });
      }
      throw error;
    }

    // 알림 생성
    try {
      const { data: listing } = await supabase
        .from('marketplace_listings')
        .select('title, posted_by')
        .eq('id', id)
        .maybeSingle();

      if (listing) {
        await supabase.from('notifications').insert({
          userid: listing.posted_by,
          title: '새로운 입찰',
          body: `${listing.title || '오더'}에 새로운 입찰이 들어왔습니다.`,
          type: 'new_bid',
          jobId: id,
          isread: false,
          createdat: new Date().toISOString(),
        });
      }
    } catch (e) {
      console.warn('[market] notification failed:', e.message || e);
    }

    return res.json({ success: true, bidId: data });
  } catch (error) {
    console.error('[market] bid error:', error);
    res.status(500).json({ message: '입찰 처리 실패' });
  }
});

// POST /api/market/listings/:id/select-bidder
// Body: { bidderId, ownerId }
// 오더 소유자가 입찰자 선택
router.post('/listings/:id/select-bidder', async (req, res) => {
  try {
    const { id } = req.params;
    const { bidderId, ownerId } = req.body || {};
    if (!bidderId || !ownerId) {
      return res.status(400).json({ message: 'bidderId, ownerId는 필수입니다' });
    }

    // RPC 호출: select_bidder
    const { data, error } = await supabase.rpc('select_bidder', {
      p_listing_id: id,
      p_bidder_id: bidderId,
      p_owner_id: ownerId,
    });

    if (error) throw error;

    // 선택된 입찰자에게 알림
    try {
      const { data: listing } = await supabase
        .from('marketplace_listings')
        .select('title, jobid')
        .eq('id', id)
        .maybeSingle();

      if (listing) {
        const nowIso = new Date().toISOString();
        
        // 선택된 입찰자에게 알림
        await supabase.from('notifications').insert({
          userid: bidderId,
          title: '오더 선택됨',
          body: `${listing.title || '오더'}에 선택되었습니다!`,
          type: 'bid_selected',
          jobId: listing.jobid,
          isread: false,
          createdat: nowIso,
        });

        // 거절된 입찰자들에게 알림
        const { data: rejectedBids } = await supabase
          .from('order_bids')
          .select('bidder_id')
          .eq('listing_id', id)
          .eq('status', 'rejected');

        if (rejectedBids && rejectedBids.length > 0) {
          const rejectedNotifs = rejectedBids.map(bid => ({
            userid: bid.bidder_id,
            title: '오더가 다른 사업자에게 이관되었습니다',
            body: `${listing.title || '오더'}가 다른 사업자에게 이관되었습니다. 다음 기회를 노려보시기 바랍니다.`,
            type: 'bid_rejected',
            jobId: listing.jobid,
            isread: false,
            createdat: nowIso,
          }));
          await supabase.from('notifications').insert(rejectedNotifs);
        }

        // 채팅방 생성
        const { data: owner } = await supabase
          .from('marketplace_listings')
          .select('posted_by')
          .eq('id', id)
          .maybeSingle();

        if (owner) {
          const roomId = `order_${id}`;
          await supabase.from('chat_rooms').upsert({
            id: roomId,
            listingid: id,
            jobid: listing.jobid,
            participant_a: owner.posted_by,
            participant_b: bidderId,
            createdat: nowIso,
            updatedat: nowIso,
            active: true,
          });

          await supabase.from('chat_messages').insert({
            room_id: roomId,
            sender_id: owner.posted_by,
            content: '안녕하세요, 오더 관련 채팅방입니다',
            type: 'system',
            createdat: nowIso,
          });
        }
      }
    } catch (e) {
      console.warn('[market] notification/chat failed:', e.message || e);
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('[market] select bidder error:', error);
    res.status(500).json({ message: '입찰자 선택 실패' });
  }
});

// GET /api/market/listings/:id/bids
// 오더의 모든 입찰 조회 (오더 소유자만)
router.get('/listings/:id/bids', async (req, res) => {
  try {
    const { id } = req.params;
    
    const { data, error } = await supabase
      .from('order_bids')
      .select(`
        *,
        bidder:users!order_bids_bidder_id_fkey(id, businessname, avatar_url, estimates_created_count, jobs_accepted_count)
      `)
      .eq('listing_id', id)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    console.error('[market] get bids error:', error);
    res.status(500).json({ message: '입찰 목록 조회 실패' });
  }
});

// POST /api/market/bids/:id/withdraw
// Body: { bidderId }
// 입찰 취소
router.post('/bids/:id/withdraw', async (req, res) => {
  try {
    const { id } = req.params;
    const { bidderId } = req.body || {};
    if (!bidderId) return res.status(400).json({ message: 'bidderId는 필수입니다' });

    const { data, error } = await supabase.rpc('withdraw_bid', {
      p_bid_id: id,
      p_bidder_id: bidderId,
    });

    if (error) throw error;
    if (!data) {
      return res.status(404).json({ success: false, message: '입찰을 찾을 수 없거나 취소할 수 없습니다' });
    }

    return res.json({ success: true });
  } catch (error) {
    console.error('[market] withdraw bid error:', error);
    res.status(500).json({ message: '입찰 취소 실패' });
  }
});

// POST /api/market/listings/:id/claim
// Body: { businessId }
// [DEPRECATED] 기존 호환성 유지, 새로운 시스템에서는 /bid 사용
router.post('/listings/:id/claim', async (req, res) => {
  try {
    const { id } = req.params;
    const { businessId } = req.body || {};
    if (!businessId) return res.status(400).json({ message: 'businessId는 필수입니다' });

    // 1) Try RPC first if available
    try {
      const { data: rpcData, error: rpcErr } = await supabase.rpc('claim_listing', {
        p_listing_id: id,
        p_business_id: businessId,
      });
      if (rpcErr) throw rpcErr;
      if (rpcData === true) {
        return res.json({ success: true });
      }
      // rpcData === false -> fallback (allow self-claim for testing)
      // proceed to fallback block below
    } catch (rpcError) {
      // Fallback: atomic update via conditional WHERE
      // eslint-disable-next-line no-console
      console.warn('[market] RPC unavailable, fallback to conditional update:', rpcError.message || rpcError);
    }

    // Common fallback path (also used when RPC returned false): allow self-claim for testing
    // Fetch listing to get jobid for later sync
    const { data: listing, error: getErr } = await supabase
      .from('marketplace_listings')
      .select('id, jobid, posted_by, title')
      .eq('id', id)
      .maybeSingle();
    if (getErr) throw getErr;
    if (!listing) return res.status(404).json({ message: '존재하지 않는 항목' });

    const nowIso = new Date().toISOString();
    const { data: upd, error: updErr } = await supabase
      .from('marketplace_listings')
      .update({ status: 'assigned', claimed_by: businessId, claimed_at: nowIso, updatedat: nowIso })
      .eq('id', id)
      .eq('status', 'open')
      .is('claimed_by', null)
      .select('id')
      .maybeSingle();
    if (updErr) throw updErr;
    if (!upd) return res.status(409).json({ success: false, message: '이미 다른 사업자가 가져갔습니다' });

    // Sync job assignment (best-effort)
    if (listing.jobid) {
      await supabase
        .from('jobs')
        .update({ assigned_business_id: businessId, status: 'in_progress' })
        .eq('id', listing.jobid);
    }

    // Increment jobs_accepted_count for the assigned business
    try {
      await supabase.rpc('increment_user_jobs_accepted_count', { user_id: businessId });
    } catch (e) {
      console.warn('[market] Failed to increment jobs_accepted_count:', e.message || e);
    }

    // Notifications + Chat room (best-effort)
    try {
      const notifPayloads = [
        {
          userid: businessId,
          title: '공사를 받았습니다',
          body: `${listing.title || '공사'} 공사를 가져왔습니다.`,
          type: 'job_assigned',
          jobId: listing.jobid,
          isread: false,
          createdat: nowIso,
        },
        {
          userid: listing.posted_by,
          title: '가져가기 완료',
          body: `${businessId} 사업자가 ${listing.title || '공사'}를 가져갔습니다.`,
          type: 'job_transfer_accepted',
          jobId: listing.jobid,
          isread: false,
          createdat: nowIso,
        },
      ];
      await supabase.from('notifications').insert(notifPayloads);

      // Create/ensure chat room between poster and claimer
      const roomId = `call_${id}`;
      await supabase.from('chat_rooms').upsert({
        id: roomId,
        listingid: id,
        jobid: listing.jobid,
        participant_a: listing.posted_by,
        participant_b: businessId,
        createdat: nowIso,
        updatedat: nowIso,
        active: true,
      });
      await supabase.from('chat_messages').insert({
        room_id: roomId,
        sender_id: listing.posted_by,
        content: '콜이 배정되어 채팅이 시작되었습니다.',
        type: 'system',
        createdat: nowIso,
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('[market] notification insert failed:', e.message || e);
    }

    return res.json({ success: true });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[market] claim error:', error);
    res.status(500).json({ message: '가져가기 처리 실패' });
  }
});

module.exports = router;

// DEV-ONLY: seed one sample listing (requires admin-token)
router.post('/dev/seed', async (req, res) => {
  try {
    const token = req.headers['admin-token'] || req.headers['x-admin-token'];
    if (ADMIN_TOKEN && token !== ADMIN_TOKEN) {
      return res.status(401).json({ message: '관리자 권한이 필요합니다' });
    }

    // pick a job
    const { data: job, error: jobErr } = await supabase
      .from('jobs')
      .select('id, title, description, location, category, budget_amount, assigned_business_id, created_at')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (jobErr) throw jobErr;
    if (!job) return res.status(400).json({ message: '콜이 없습니다.' });

    // pick a business user as poster, avoid current assignee if possible
    const { data: businesses, error: buErr } = await supabase
      .from('users')
      .select('id')
      .eq('role', 'business')
      .limit(10);
    if (buErr) throw buErr;
    const poster = (businesses || []).find(u => u.id !== job.assigned_business_id) || (businesses || [])[0];
    if (!poster) return res.status(400).json({ message: '사업자 계정이 없습니다' });

    const nowIso = new Date().toISOString();
    const payload = {
      jobid: job.id,
      title: job.title || 'CAll 샘플 공사',
      description: job.description || 'Call 테스트용 샘플 항목',
      region: job.location || null,
      category: job.category || null,
      budget_amount: typeof job.budget_amount === 'number' ? job.budget_amount : (typeof job.budgetamount === 'number' ? job.budgetamount : null),
      posted_by: poster.id,
      status: 'open',
      createdat: nowIso,
      updatedat: nowIso,
    };

    const { data: ins, error: insErr } = await supabase
      .from('marketplace_listings')
      .insert([payload])
      .select()
      .maybeSingle();
    if (insErr) throw insErr;
    return res.status(201).json(ins);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[market] seed error:', error);
    res.status(500).json({ message: '시드 생성 실패' });
  }
});


