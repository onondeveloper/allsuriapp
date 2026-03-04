const express = require('express');
const router = express.Router();
const AdminMessage = require('../models/admin-message');
const AdminStatistics = require('../models/admin-statistics');
// const User = require('../models/user');
// const Estimate = require('../models/estimate');
// const Order = require('../models/order');
const { supabase } = require('../config/supabase');
const { sendPushNotification } = require('../services/fcm_service');

// 미들웨어: 관리자 권한 확인 (헤더 토큰 + 환경변수 검증)
const ADMIN_TOKEN = process.env.ADMIN_TOKEN; // legacy token -> developer 취급
const ADMIN_DEVELOPER_TOKEN = process.env.ADMIN_DEVELOPER_TOKEN;
const ADMIN_STAFF_TOKEN = process.env.ADMIN_STAFF_TOKEN;
const ADMIN_BUSINESS_TOKEN = process.env.ADMIN_BUSINESS_TOKEN;
if (!ADMIN_TOKEN && !ADMIN_DEVELOPER_TOKEN && !ADMIN_STAFF_TOKEN && !ADMIN_BUSINESS_TOKEN) {
  // eslint-disable-next-line no-console
  console.warn('[admin] No admin tokens set. Any non-empty admin-token header will be accepted (dev only).');
}

const requireAdmin = (req, res, next) => {
  try {
    const token =
      req.headers['admin-token'] ||
      req.headers['x-admin-token'] ||
      req.query.admin_token ||
      req.query.token;

    // 디버그 로그 (필요 시 축소 가능)
    console.log('[ADMIN AUTH] Request headers:', req.headers);
    console.log('[ADMIN AUTH] Query params:', req.query);
    console.log('[ADMIN AUTH] Extracted token:', token);

    if (!token) return res.status(401).json({ message: '관리자 권한이 필요합니다' });

    let role = null;
    if (ADMIN_DEVELOPER_TOKEN && token === ADMIN_DEVELOPER_TOKEN) role = 'developer';
    else if (ADMIN_STAFF_TOKEN && token === ADMIN_STAFF_TOKEN) role = 'staff';
    else if (ADMIN_BUSINESS_TOKEN && token === ADMIN_BUSINESS_TOKEN) role = 'business';
    else if (ADMIN_TOKEN && token === ADMIN_TOKEN) role = 'developer'; // legacy 호환
    else if (!ADMIN_TOKEN && !ADMIN_DEVELOPER_TOKEN && !ADMIN_STAFF_TOKEN && !ADMIN_BUSINESS_TOKEN) role = 'developer'; // dev fallback

    if (!role) return res.status(401).json({ message: '관리자 권한이 필요합니다' });
    req.admin = { role };
    next();
  } catch (error) {
    res.status(401).json({ message: '인증 실패' });
  }
};

// 모든 라우트에 관리자 권한 미들웨어 적용
router.use(requireAdmin);

// 권한 체크 미들웨어
const requireRole = (...allowed) => (req, res, next) => {
  const role = req.admin?.role || 'business';
  if (allowed.includes(role) || allowed.includes('any')) return next();
  return res.status(403).json({ message: '권한이 없습니다' });
};

// 현재 관리자 정보
router.get('/me', (req, res) => {
  const role = req.admin?.role || 'business';
  const permissions = {
    canViewDashboard: true,
    canManageUsers: role === 'developer' || role === 'staff',
    canManageAds: role === 'developer' || role === 'staff',
    canViewEstimates: true,
    canEditEstimates: role === 'developer' || role === 'staff',
    canViewBillings: role === 'developer',
    canManageSettings: role === 'developer',
  };
  res.json({ role, permissions });
});

// 광고 CRUD (Supabase ads 테이블 사용: id, title, slug, html_path, status, priority, createdat)
router.get('/ads', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { data, error } = await supabase.from('ads').select('*').order('createdat', { ascending: false });
    if (error) throw error;
    res.json(data || []);
  } catch (e) {
    res.status(500).json({ message: '광고 목록 조회 실패' });
  }
});

router.post('/ads', requireRole('developer', 'staff'), async (req, res) => {
  try {
    console.log('[ADMIN] POST /ads - Received payload:', req.body);
    const payload = req.body || {};
    payload.createdat = new Date().toISOString();
    console.log('[ADMIN] POST /ads - Inserting payload:', payload);
    const { data, error } = await supabase.from('ads').insert(payload).select('*').single();
    if (error) {
      console.error('[ADMIN] POST /ads - Supabase error:', error);
      throw error;
    }
    console.log('[ADMIN] POST /ads - Success:', data);
    res.status(201).json(data);
  } catch (e) {
    console.error('[ADMIN] POST /ads - Error:', e);
    res.status(500).json({ 
      message: '광고 생성 실패', 
      error: e.message || e.toString(),
      details: e.details || e.hint || null
    });
  }
});

router.put('/ads/:id', requireRole('developer', 'staff'), async (req, res) => {
  try {
    console.log('[ADMIN] PUT /ads/:id - ID:', req.params.id, 'Payload:', req.body);
    const { data, error } = await supabase.from('ads').update(req.body || {}).eq('id', req.params.id).select('*').maybeSingle();
    if (error) {
      console.error('[ADMIN] PUT /ads/:id - Supabase error:', error);
      throw error;
    }
    console.log('[ADMIN] PUT /ads/:id - Success:', data);
    res.json(data);
  } catch (e) {
    console.error('[ADMIN] PUT /ads/:id - Error:', e);
    res.status(500).json({ 
      message: '광고 업데이트 실패',
      error: e.message || e.toString(),
      details: e.details || e.hint || null
    });
  }
});

router.delete('/ads/:id', requireRole('developer'), async (req, res) => {
  try {
    console.log('[ADMIN] DELETE /ads/:id - ID:', req.params.id);
    const { error } = await supabase.from('ads').delete().eq('id', req.params.id);
    if (error) {
      console.error('[ADMIN] DELETE /ads/:id - Supabase error:', error);
      throw error;
    }
    console.log('[ADMIN] DELETE /ads/:id - Success');
    res.json({ message: '광고 삭제 완료' });
  } catch (e) {
    console.error('[ADMIN] DELETE /ads/:id - Error:', e);
    res.status(500).json({ 
      message: '광고 삭제 실패',
      error: e.message || e.toString(),
      details: e.details || e.hint || null
    });
  }
});

// 광고 통계 (간단 집계)
router.get('/ads/stats', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ads_events')
      .select('ad_id, type, count:count(*)')
      .group('ad_id, type');
    if (error) throw error;
    res.json(data || []);
  } catch (e) {
    res.status(500).json({ message: '광고 통계 조회 실패' });
  }
});

// 대시보드 데이터
router.get('/dashboard', async (req, res) => {
  let users, estimatesAll, orders;
  
  try {
    console.log('[ADMIN DASHBOARD] Starting dashboard data fetch...');
    
    // 사용자 통계
    const usersResult = await supabase.from('users').select('id, role');
    users = usersResult.data;
    
    if (usersResult.error) {
      console.error('[ADMIN DASHBOARD] Users error:', usersResult.error);
      throw usersResult.error;
    }
    console.log('[ADMIN DASHBOARD] Users count:', users?.length || 0);
    
    const totalUsers = (users || []).length;
    const totalBusinessUsers = (users || []).filter(u => u.role === 'business').length;
    const totalCustomers = (users || []).filter(u => u.role === 'customer').length;

    // 견적 통계 - amount 컬럼만 사용 (estimatedprice, estimatedPrice는 존재하지 않음)
    const estimatesResult = await supabase
      .from('estimates')
      .select('id, status, amount, createdat');
    
    estimatesAll = estimatesResult.data;
    
    if (estimatesResult.error) {
      console.error('[ADMIN DASHBOARD] Estimates error:', estimatesResult.error);
      throw estimatesResult.error;
    }
    console.log('[ADMIN DASHBOARD] Estimates count:', estimatesAll?.length || 0);
    console.log('[ADMIN DASHBOARD] Estimates data sample:', estimatesAll?.slice(0, 3));

    const estimates = estimatesAll || [];
    const totalEstimates = estimates.length;
    const pendingEstimates = estimates.filter(e => e.status === 'pending').length;
    const approvedEstimates = estimates.filter(e => e.status === 'approved').length;
    const completedEstimates = estimates.filter(e => e.status === 'completed').length;
    const inProgressEstimates = estimates.filter(e => e.status === 'in_progress').length;
    const awardedEstimates = estimates.filter(e => e.status === 'awarded').length;
    const transferredEstimates = estimates.filter(e => e.status === 'transferred').length;

    // 수익 계산 - 완료된 견적 금액의 5%
    const getAmount = (row) => {
      // amount 컬럼만 확인
      if (typeof row.amount === 'number' && !isNaN(row.amount)) return row.amount;
      return 0;
    };
    
    // 완료된 견적의 총 금액 계산
    // completed, awarded, transferred 상태의 견적 모두 포함
    const completedStatuses = ['completed', 'awarded', 'transferred'];
    const completed = estimates.filter(e => completedStatuses.includes(e.status));
    const totalEstimateAmount = completed.reduce((sum, e) => {
      const amount = getAmount(e);
      console.log(`[ADMIN DASHBOARD] Estimate amount: ${amount}, status: ${e.status}`);
      return sum + amount;
    }, 0);
    
    console.log('[ADMIN DASHBOARD] Total estimate amount:', totalEstimateAmount);
    console.log('[ADMIN DASHBOARD] Completed estimates count:', completed.length);
    
    // 완료된 견적의 5% 수익
    const totalRevenue = totalEstimateAmount * 0.05;
    
    const averageEstimateAmount = completed.length > 0
      ? totalEstimateAmount / completed.length
      : 0;

    // 오더 현황 통계 (marketplace_listings 테이블)
    let listings;
    const listingsResult = await supabase
      .from('marketplace_listings')
      .select('id, status, claimed_by, budget_amount, createdat');
    
    listings = listingsResult.data;
    
    if (listingsResult.error) {
      console.error('[ADMIN DASHBOARD] Listings error:', listingsResult.error);
      // Listings 에러는 치명적이지 않으므로 계속 진행
    }

    console.log('[ADMIN DASHBOARD] Listings count:', listings?.length || 0);
    console.log('[ADMIN DASHBOARD] Listings sample:', listings?.slice(0, 3));
    
    // 각 status별 카운트 로깅
    const statusCounts = (listings || []).reduce((acc, l) => {
      acc[l.status] = (acc[l.status] || 0) + 1;
      return acc;
    }, {});
    console.log('[ADMIN DASHBOARD] Listings by status:', statusCounts);

    const totalOrders = (listings || []).length;
    // 입찰 중: status가 'created' 또는 'open'이고 아직 claimed_by가 없는 경우
    const pendingOrders = (listings || []).filter(l => 
      (l.status === 'created' || l.status === 'open') && !l.claimed_by
    ).length;
    // 완료: status가 'assigned'이거나 claimed_by가 있는 경우
    const completedOrdersList = (listings || []).filter(l => 
      l.status === 'assigned' || l.claimed_by
    );
    const completedOrders = completedOrdersList.length;
    
    // 완료된 오더의 총 예산 금액
    const totalOrderAmount = completedOrdersList.reduce((sum, l) => {
      const budget = l.budget_amount || 0;
      console.log(`[ADMIN DASHBOARD] Order budget: ${budget}, status: ${l.status}`);
      return sum + budget;
    }, 0);
    
    console.log('[ADMIN DASHBOARD] Orders breakdown - Total:', totalOrders, 'Pending:', pendingOrders, 'Completed:', completedOrders);
    console.log('[ADMIN DASHBOARD] Total order amount:', totalOrderAmount);

    // Jobs 테이블 통계 (기존 jobs 테이블)
    let jobs;
    const jobsResult = await supabase
      .from('jobs')
      .select('id, status, createdat');
    
    jobs = jobsResult.data;
    
    if (jobsResult.error) {
      console.error('[ADMIN DASHBOARD] Jobs error:', jobsResult.error);
    }

    const totalJobs = (jobs || []).length;
    const pendingJobs = (jobs || []).filter(j => j.status === 'pending').length;
    const completedJobs = (jobs || []).filter(j => j.status === 'completed').length;

    const dashboardData = {
      totalBusinessUsers,
      totalCustomers,
      totalEstimates,
      pendingEstimates,
      approvedEstimates,
      completedEstimates,
      inProgressEstimates,
      awardedEstimates,
      transferredEstimates,
      totalEstimateAmount: Math.round(totalEstimateAmount),
      totalRevenue: Math.round(totalRevenue),
      averageEstimateAmount: Math.round(averageEstimateAmount),
      totalOrders,
      pendingOrders,
      completedOrders,
      totalOrderAmount: Math.round(totalOrderAmount),
      totalJobs,
      pendingJobs,
      completedJobs,
    };

    console.log('[ADMIN DASHBOARD] Dashboard data:', dashboardData);
    res.json(dashboardData);
  } catch (error) {
    console.error('[admin/dashboard] error:', error);
    res.status(500).json({ 
      message: '대시보드 데이터 조회 실패', 
      error: String(error?.message || error),
      debug: {
        hasUsers: !!users,
        hasEstimates: !!estimatesAll,
        hasOrders: !!orders
      }
    });
  }
});

// 오더 현황 목록 조회 (marketplace_listings 테이블)
router.get('/calls', async (req, res) => {
  try {
    console.log('[ADMIN ORDERS] Fetching marketplace listings data...');
    
    const { data: listings, error } = await supabase
      .from('marketplace_listings')
      .select(`
        id,
        title,
        description,
        posted_by,
        claimed_by,
        claimed_at,
        budget_amount,
        status,
        region,
        category,
        createdat,
        updatedat,
        media_urls,
        bid_count
      `)
      .order('createdat', { ascending: false });
    
    if (error) {
      console.error('[ADMIN ORDERS] Error:', error);
      throw error;
    }
    
    console.log('[ADMIN ORDERS] Listings count:', listings?.length || 0);
    
    // 사업자 정보 가져오기
    const ownerIds = [...new Set(listings?.map(l => l.posted_by).filter(Boolean) || [])];
    const claimedIds = [...new Set(listings?.map(l => l.claimed_by).filter(Boolean) || [])];
    const allUserIds = [...new Set([...ownerIds, ...claimedIds])];
    
    let usersMap = {};
    if (allUserIds.length > 0) {
      const { data: users } = await supabase
        .from('users')
        .select('id, name, businessname, phonenumber')
        .in('id', allUserIds);
      
      usersMap = (users || []).reduce((acc, user) => {
        acc[user.id] = user;
        return acc;
      }, {});
    }
    
    // 사업자 정보를 포함한 데이터 반환
    const listingsWithUsers = (listings || []).map(listing => ({
      ...listing,
      owner_business_name: usersMap[listing.posted_by]?.businessname || usersMap[listing.posted_by]?.name || '알 수 없음',
      assigned_business_name: listing.claimed_by ? (usersMap[listing.claimed_by]?.businessname || usersMap[listing.claimed_by]?.name || '알 수 없음') : null,
      created_at: listing.createdat,
      updated_at: listing.updatedat,
      location: listing.region,
    }));
    
    res.json(listingsWithUsers);
  } catch (error) {
    console.error('[admin/orders] error:', error);
    res.status(500).json({ message: '오더 현황 조회 실패', error: String(error?.message || error) });
  }
});

// 메시징 기능
router.get('/messages', async (req, res) => {
  try {
    const messages = await AdminMessage.find().sort({ createdAt: -1 });
    res.json(messages);
  } catch (error) {
    res.status(500).json({ message: '메시지 조회 실패' });
  }
});

router.post('/messages', async (req, res) => {
  try {
    const message = new AdminMessage({
      ...req.body,
      createdAt: new Date(),
      status: req.body.status || 'draft',
    });
    await message.save();
    res.status(201).json(message);
  } catch (error) {
    res.status(500).json({ message: '메시지 생성 실패' });
  }
});

router.delete('/messages/:id', async (req, res) => {
  try {
    await AdminMessage.findByIdAndDelete(req.params.id);
    res.json({ message: '메시지 삭제 완료' });
  } catch (error) {
    res.status(500).json({ message: '메시지 삭제 실패' });
  }
});

// 통계 기능
router.get('/statistics', async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalBusinessUsers = await User.countDocuments({ role: 'business' });
    const totalCustomers = await User.countDocuments({ role: 'customer' });
    const totalEstimates = await Estimate.countDocuments();
    const completedEstimates = await Estimate.countDocuments({ status: 'completed' });
    const pendingEstimates = await Estimate.countDocuments({ status: 'pending' });

    // 지역별 견적 분포
    const estimatesByRegion = await Estimate.aggregate([
      { $group: { _id: '$region', count: { $sum: 1 } } }
    ]);

    // 서비스별 견적 분포
    const estimatesByService = await Estimate.aggregate([
      { $group: { _id: '$serviceType', count: { $sum: 1 } } }
    ]);

    // 수익 계산
    const estimates = await Estimate.find({ status: 'completed' });
    const totalRevenue = estimates.reduce((sum, estimate) => sum + (estimate.amount * 0.05), 0);
    const averageEstimateAmount = estimates.length > 0 ? estimates.reduce((sum, estimate) => sum + estimate.amount, 0) / estimates.length : 0;

    const statistics = new AdminStatistics({
      id: new Date().toISOString(),
      date: new Date(),
      totalUsers,
      totalBusinessUsers,
      totalCustomers,
      totalEstimates,
      completedEstimates,
      pendingEstimates,
      totalRevenue,
      averageEstimateAmount,
      estimatesByRegion: estimatesByRegion.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
      estimatesByService: estimatesByService.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
      businessBillings: [],
    });

    res.json(statistics);
  } catch (error) {
    res.status(500).json({ message: '통계 조회 실패' });
  }
});

// 사업자별 과금 현황
router.get('/business-billings', async (req, res) => {
  try {
    const businessUsers = await User.find({ role: 'business' });
    const billings = [];

    for (const business of businessUsers) {
      const estimates = await Estimate.find({ businessId: business._id });
      const completedEstimates = estimates.filter(e => e.status === 'completed');
      const bidCount = estimates.length;
      const winCount = completedEstimates.length;
      const winRate = bidCount > 0 ? (winCount / bidCount) * 100 : 0;
      const monthlyRevenue = completedEstimates.reduce((sum, estimate) => sum + (estimate.amount * 0.05), 0);

      billings.push({
        businessId: business._id.toString(),
        businessName: business.name || business.email,
        region: business.serviceAreas?.[0] || '미지정',
        bidCount,
        winCount,
        winRate,
        monthlyRevenue,
        services: business.specialties || [],
        lastActivity: business.updatedAt || business.createdAt,
      });
    }

    res.json(billings);
  } catch (error) {
    res.status(500).json({ message: '과금 현황 조회 실패' });
  }
});

// 사용자 관리
router.get('/users', async (req, res) => {
  try {
    const { data, error } = await supabase.from('users').select('*').order('createdAt', { ascending: false });
    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    res.status(500).json({ message: '사용자 조회 실패' });
  }
});

router.patch('/users/:id/status', async (req, res) => {
  try {
    const { status } = req.body; // pending/approved/rejected
    const userId = req.params.id;
    console.log('[ADMIN] 사용자 상태 업데이트:', { userId, status });
    
    // 1. 사용자 상태 업데이트
    const { data, error } = await supabase
      .from('users')
      .update({ businessstatus: status })
      .eq('id', userId)
      .select()
      .maybeSingle();
    
    if (error) {
      console.error('[ADMIN] 업데이트 에러:', error);
      throw error;
    }
    console.log('[ADMIN] 업데이트 성공:', data);
    
    // 2. 승인 시 알림 전송 (DB + FCM 푸시)
    if (status === 'approved' && data) {
      try {
        const notificationData = {
          userid: userId,
          title: '🎉 사업자 승인 완료',
          body: `${data.businessname || data.name}님의 사업자 계정이 승인되었습니다. 이제 견적 요청을 받을 수 있습니다!`,
          type: 'business_approved',
          isread: false,
          createdat: new Date().toISOString(),
        };
        
        // DB에 알림 저장
        const { error: notifError } = await supabase
          .from('notifications')
          .insert(notificationData);
        
        if (notifError) {
          console.error('[ADMIN] 알림 전송 실패:', notifError);
        } else {
          console.log('[ADMIN] 승인 알림 전송 완료:', userId);
        }
        
        // FCM 푸시 알림 전송
        await sendPushNotification(
          userId,
          {
            title: notificationData.title,
            body: notificationData.body,
          },
          {
            type: 'business_approved',
            businessName: data.businessname || data.name || '',
          }
        );
      } catch (notifErr) {
        console.error('[ADMIN] 알림 전송 오류:', notifErr);
        // 알림 실패해도 승인은 성공으로 처리
      }
    }
    
    // 3. 거절 시 알림 전송 (DB + FCM 푸시)
    if (status === 'rejected' && data) {
      try {
        const notificationData = {
          userid: userId,
          title: '사업자 승인 거절',
          body: '사업자 계정 승인이 거절되었습니다. 자세한 사항은 고객센터로 문의해주세요.',
          type: 'business_rejected',
          isread: false,
          createdat: new Date().toISOString(),
        };
        
        // DB에 알림 저장
        const { error: notifError } = await supabase
          .from('notifications')
          .insert(notificationData);
        
        if (notifError) {
          console.error('[ADMIN] 알림 전송 실패:', notifError);
        } else {
          console.log('[ADMIN] 거절 알림 전송 완료:', userId);
        }
        
        // FCM 푸시 알림 전송
        await sendPushNotification(
          userId,
          {
            title: notificationData.title,
            body: notificationData.body,
          },
          {
            type: 'business_rejected',
          }
        );
      } catch (notifErr) {
        console.error('[ADMIN] 알림 전송 오류:', notifErr);
      }
    }
    
    res.json({ success: true, data });
  } catch (error) {
    console.error('[ADMIN] 상태 업데이트 실패:', error);
    res.status(500).json({ success: false, message: '사용자 상태 업데이트 실패', error: error.message });
  }
});

router.delete('/users/:id', async (req, res) => {
  try {
    console.log(`[ADMIN] 사용자 삭제 시작: userId=${req.params.id}`);
    
    // CASCADE 삭제 함수 사용 (모든 관련 데이터 삭제)
    const { data, error } = await supabase.rpc('delete_user_cascade', {
      user_id_to_delete: req.params.id
    });
    
    if (error) throw error;
    
    console.log(`[ADMIN] 사용자 삭제 완료:`, data);
    
    res.json({ 
      success: true, 
      message: '사용자가 삭제되었습니다',
      deleted_counts: data 
    });
  } catch (error) {
    console.error('[ADMIN] 사용자 삭제 실패:', error);
    res.status(500).json({ success: false, message: '사용자 삭제 실패', error: error.message });
  }
});

// 사용자 검색
router.get('/users/search', async (req, res) => {
  try {
    const { q, type, status } = req.query;
    let qb = supabase.from('users').select('*');
    if (q) qb = qb.or(`name.ilike.%${q}%,email.ilike.%${q}%`);
    if (type && type !== '전체') qb = qb.eq('role', type === '사업자' ? 'business' : 'customer');
    if (status && status !== '전체') qb = qb.eq('businessStatus', status);
    const { data, error } = await qb.order('createdAt', { ascending: false });
    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    res.status(500).json({ message: '사용자 검색 실패' });
  }
});

// 견적 관리 (estimates 테이블 사용)
router.get('/estimates', async (req, res) => {
  try {
    const { status, startDate, endDate, phone } = req.query;
    let qb = supabase.from('estimates').select('*');
    if (status && status !== 'all') qb = qb.eq('status', status);
    if (startDate) qb = qb.gte('createdat', startDate);
    if (endDate) qb = qb.lte('createdat', `${endDate}T23:59:59`);

    const { data: baseData, error } = await qb.order('createdat', { ascending: false });
    if (error) throw error;

    // 전화번호 필터: 사업자 전화(businessphone) 또는 주문의 고객 전화(customerPhone)
    let result = baseData || [];
    if (phone && phone.trim()) {
      const phoneQuery = phone.trim();
      // 일단 businessphone으로 1차 필터
      result = result.filter((e) => (e.businessphone || '').includes(phoneQuery));

      // 고객 전화도 검사: orders에서 customerPhone 매칭되는 orderId 모아 교집합 추가
      const { data: orders, error: ordersErr } = await supabase
        .from('orders')
        .select('id, customerPhone')
        .ilike('customerPhone', `%${phoneQuery}%`);
      if (!ordersErr && orders) {
        const orderIdSet = new Set(orders.map((o) => o.id));
        const extra = (baseData || []).filter((e) => orderIdSet.has(e.orderId));
        // merge unique by id
        const byId = new Map(result.map((r) => [r.id, r]));
        for (const row of extra) byId.set(row.id, row);
        result = Array.from(byId.values());
      }
    }

    res.json(result);
  } catch (error) {
    res.status(500).json({ message: '견적 조회 실패' });
  }
});

router.patch('/estimates/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const { data, error } = await supabase.from('estimates').update({ status }).eq('id', req.params.id).select().maybeSingle();
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: '견적 상태 업데이트 실패' });
  }
});

// 견적 검색
router.get('/estimates/search', async (req, res) => {
  try {
    const { q, status } = req.query;
    let qb = supabase.from('estimates').select('*');
    if (q) qb = qb.or(`description.ilike.%${q}%,customername.ilike.%${q}%,businessname.ilike.%${q}%`);
    if (status && status !== '전체') qb = qb.eq('status', status);
    const { data, error } = await qb.order('createdat', { ascending: false });
    if (error) throw error;
    res.json(data || []);
  } catch (error) {
    res.status(500).json({ message: '견적 검색 실패' });
  }
});

// 시스템 설정
router.get('/settings', async (req, res) => {
  try {
    // 실제로는 데이터베이스에서 설정을 가져와야 함
    const settings = {
      emailNotifications: true,
      smsNotifications: false,
      autoApprove: false,
      commissionRate: 0.05,
      maxEstimatesPerUser: 10,
    };
    res.json(settings);
  } catch (error) {
    res.status(500).json({ message: '설정 조회 실패' });
  }
});

router.put('/settings', async (req, res) => {
  try {
    // 실제로는 데이터베이스에 설정을 저장해야 함
    const settings = req.body;
    res.json({ message: '설정 업데이트 완료', settings });
  } catch (error) {
    res.status(500).json({ message: '설정 업데이트 실패' });
  }
});

// ==========================================
// 관리자 권한 관리 API
// ==========================================

// 사용자를 관리자로 지정/해제
router.patch('/users/:userId/admin', requireRole('developer'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { is_admin } = req.body;
    
    console.log(`[ADMIN] 관리자 권한 변경: userId=${userId}, is_admin=${is_admin}`);
    
    const { data, error } = await supabase
      .from('users')
      .update({ is_admin })
      .eq('id', userId)
      .select('id, name, email, is_admin')
      .single();
    
    if (error) throw error;
    
    res.json({ 
      success: true, 
      message: is_admin ? '관리자로 지정되었습니다' : '관리자 권한이 해제되었습니다',
      data 
    });
  } catch (error) {
    console.error('[ADMIN] 관리자 권한 변경 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 사업자 삭제 (CASCADE)
router.delete('/users/:userId/delete-business', requireRole('developer'), async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`[ADMIN] 사업자 삭제 시작: userId=${userId}`);
    
    // Supabase Function 호출
    const { data, error } = await supabase.rpc('delete_business_user', {
      user_id_to_delete: userId
    });
    
    if (error) throw error;
    
    console.log(`[ADMIN] 사업자 삭제 완료:`, data);
    
    res.json({ 
      success: true, 
      message: '사업자가 삭제되었습니다',
      data 
    });
  } catch (error) {
    console.error('[ADMIN] 사업자 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 공사 삭제 (관리자 전용)
router.delete('/jobs/:jobId', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { jobId } = req.params;
    
    console.log(`[ADMIN] 공사 삭제: jobId=${jobId}`);
    
    const { error } = await supabase
      .from('jobs')
      .delete()
      .eq('id', jobId);
    
    if (error) throw error;
    
    res.json({ success: true, message: '공사가 삭제되었습니다' });
  } catch (error) {
    console.error('[ADMIN] 공사 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 오더 삭제 (관리자 전용)
router.delete('/listings/:listingId', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { listingId } = req.params;
    
    console.log(`[ADMIN] 오더 삭제: listingId=${listingId}`);
    
    const { error } = await supabase
      .from('marketplace_listings')
      .delete()
      .eq('id', listingId);
    
    if (error) throw error;
    
    res.json({ success: true, message: '오더가 삭제되었습니다' });
  } catch (error) {
    console.error('[ADMIN] 오더 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 커뮤니티 게시글 삭제 (관리자 전용) 테스트
router.delete('/posts/:postId', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { postId } = req.params;
    
    console.log(`[ADMIN] 게시글 삭제: postId=${postId}`);
    
    const { error } = await supabase
      .from('community_posts')
      .delete()
      .eq('id', postId);
    
    if (error) throw error;
    
    res.json({ success: true, message: '게시글이 삭제되었습니다' });
  } catch (error) {
    console.error('[ADMIN] 게시글 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 커뮤니티 댓글 삭제 (관리자 전용)
router.delete('/comments/:commentId', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { commentId } = req.params;
    
    console.log(`[ADMIN] 댓글 삭제: commentId=${commentId}`);
    
    const { error } = await supabase
      .from('community_comments')
      .delete()
      .eq('id', commentId);
    
    if (error) throw error;
    
    res.json({ success: true, message: '댓글이 삭제되었습니다' });
  } catch (error) {
    console.error('[ADMIN] 댓글 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 오더 전체 프로세스 조회 (낙찰→진행→완료→후기)
router.get('/listings/:listingId/process', async (req, res) => {
  try {
    const { listingId } = req.params;

    // 1. 오더 기본 정보
    const { data: listing, error: listingErr } = await supabase
      .from('marketplace_listings')
      .select('*, jobs(commission_rate, media_urls)')
      .eq('id', listingId)
      .maybeSingle();
    if (listingErr) throw listingErr;
    if (!listing) return res.status(404).json({ message: '오더를 찾을 수 없습니다' });

    // 2. 입찰 목록 (listing_id OR job_id OR listing_id=jobid 한 번에 or 쿼리로 조회)
    const jobid = listing.jobid ?? listing.jobId;
    const orConditions = [`listing_id.eq.${listingId}`];
    if (jobid) orConditions.push(`job_id.eq.${jobid}`, `listing_id.eq.${jobid}`);
    const { data: bids } = await supabase
      .from('order_bids')
      .select('id, bidder_id, bid_amount, message, status, created_at')
      .or(orConditions.join(','))
      .order('created_at', { ascending: true });

    // 3. 후기
    const { data: reviews } = await supabase
      .from('order_reviews')
      .select('id, reviewer_id, reviewee_id, rating, tags, comment, created_at')
      .eq('listing_id', listingId)
      .order('created_at', { ascending: false });

    // 4. 참여자 ID 수집
    const userIds = [...new Set([
      listing.posted_by,
      listing.claimed_by,
      ...(bids || []).map(b => b.bidder_id),
      ...(reviews || []).map(r => r.reviewer_id),
      ...(reviews || []).map(r => r.reviewee_id),
    ].filter(Boolean))];

    let usersMap = {};
    if (userIds.length > 0) {
      const { data: users } = await supabase
        .from('users')
        .select('id, name, businessname, phonenumber, role')
        .in('id', userIds);
      usersMap = (users || []).reduce((acc, u) => { acc[u.id] = u; return acc; }, {});
    }

    const getUser = (id) => usersMap[id] || null;
    const getUserName = (id) => {
      const u = getUser(id);
      if (!u) return '알 수 없음';
      return u.businessname || u.name || '알 수 없음';
    };

    // 낙찰된 입찰 정보 (claimed_by 기준)
    const winnerBid = listing.claimed_by
      ? (bids || []).find(b => b.bidder_id === listing.claimed_by) || null
      : null;

    res.json({
      listing: {
        ...listing,
        owner_name: getUserName(listing.posted_by),
        winner_name: listing.claimed_by ? getUserName(listing.claimed_by) : null,
        owner_phone: getUser(listing.posted_by)?.phonenumber || null,
        winner_phone: listing.claimed_by ? getUser(listing.claimed_by)?.phonenumber || null : null,
      },
      bids: (bids || []).map(b => ({
        ...b,
        bidder_name: getUserName(b.bidder_id),
        is_winner: b.bidder_id === listing.claimed_by,
      })),
      winner_bid: winnerBid,
      reviews: (reviews || []).map(r => ({
        ...r,
        reviewer_name: getUserName(r.reviewer_id),
        reviewee_name: getUserName(r.reviewee_id),
      })),
    });
  } catch (error) {
    console.error('[ADMIN] 오더 프로세스 조회 실패:', error);
    res.status(500).json({ message: '오더 프로세스 조회 실패', error: error.message });
  }
});

// 오더 상태 업데이트 (관리자 전용)
router.patch('/listings/:listingId/status', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { listingId } = req.params;
    const { status } = req.body;
    const { data, error } = await supabase
      .from('marketplace_listings')
      .update({ status, updatedat: new Date().toISOString() })
      .eq('id', listingId)
      .select()
      .maybeSingle();
    if (error) throw error;
    res.json({ success: true, data });
  } catch (error) {
    console.error('[ADMIN] 오더 상태 업데이트 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 커뮤니티 게시글 목록 조회 (관리자 전용)
router.get('/posts', async (req, res) => {
  try {
    const { data: posts, error } = await supabase
      .from('community_posts')
      .select('id, title, content, author_id, created_at, updated_at, likes_count, comments_count, is_active, category')
      .order('created_at', { ascending: false })
      .limit(200);
    if (error) throw error;

    // 작성자 정보 조회
    const authorIds = [...new Set((posts || []).map(p => p.author_id).filter(Boolean))];
    let usersMap = {};
    if (authorIds.length > 0) {
      const { data: users } = await supabase
        .from('users')
        .select('id, name, businessname, role')
        .in('id', authorIds);
      usersMap = (users || []).reduce((acc, u) => { acc[u.id] = u; return acc; }, {});
    }

    const result = (posts || []).map(p => ({
      ...p,
      author_name: usersMap[p.author_id]?.businessname || usersMap[p.author_id]?.name || '알 수 없음',
      author_role: usersMap[p.author_id]?.role || 'unknown',
    }));

    res.json(result);
  } catch (error) {
    console.error('[ADMIN] 게시글 조회 실패:', error);
    res.status(500).json({ message: '게시글 조회 실패', error: error.message });
  }
});

// 채팅방 목록 조회 (관리자 전용)
router.get('/chats', async (req, res) => {
  try {
    const { data: rooms, error } = await supabase
      .from('chat_rooms')
      .select('id, participant_a, participant_b, status, created_at, updated_at, last_message, last_message_at')
      .order('last_message_at', { ascending: false, nullsFirst: false })
      .limit(200);
    if (error) throw error;

    // 참여자 정보 조회
    const participantIds = [...new Set((rooms || []).flatMap(r => [r.participant_a, r.participant_b]).filter(Boolean))];
    let usersMap = {};
    if (participantIds.length > 0) {
      const { data: users } = await supabase
        .from('users')
        .select('id, name, businessname, role')
        .in('id', participantIds);
      usersMap = (users || []).reduce((acc, u) => { acc[u.id] = u; return acc; }, {});
    }

    const getUserName = (id) => {
      if (!id || !usersMap[id]) return '알 수 없음';
      return usersMap[id].businessname || usersMap[id].name || '알 수 없음';
    };

    const result = (rooms || []).map(r => ({
      ...r,
      participant_a_name: getUserName(r.participant_a),
      participant_b_name: getUserName(r.participant_b),
      participant_a_role: usersMap[r.participant_a]?.role || 'unknown',
      participant_b_role: usersMap[r.participant_b]?.role || 'unknown',
    }));

    res.json(result);
  } catch (error) {
    console.error('[ADMIN] 채팅방 조회 실패:', error);
    res.status(500).json({ message: '채팅방 조회 실패', error: error.message });
  }
});

// 채팅방 메시지 조회 (관리자 전용)
router.get('/chats/:roomId/messages', async (req, res) => {
  try {
    const { roomId } = req.params;
    const { data: messages, error } = await supabase
      .from('chat_messages')
      .select('id, sender_id, content, image_url, video_url, created_at, message_type')
      .eq('room_id', roomId)
      .order('created_at', { ascending: true })
      .limit(100);
    if (error) throw error;

    const senderIds = [...new Set((messages || []).map(m => m.sender_id).filter(Boolean))];
    let usersMap = {};
    if (senderIds.length > 0) {
      const { data: users } = await supabase
        .from('users')
        .select('id, name, businessname, role')
        .in('id', senderIds);
      usersMap = (users || []).reduce((acc, u) => { acc[u.id] = u; return acc; }, {});
    }

    const result = (messages || []).map(m => ({
      ...m,
      sender_name: usersMap[m.sender_id]?.businessname || usersMap[m.sender_id]?.name || '알 수 없음',
    }));

    res.json(result);
  } catch (error) {
    console.error('[ADMIN] 채팅 메시지 조회 실패:', error);
    res.status(500).json({ message: '채팅 메시지 조회 실패', error: error.message });
  }
});

// 채팅방 삭제 (관리자 전용)
router.delete('/chats/:roomId', requireRole('developer'), async (req, res) => {
  try {
    const { roomId } = req.params;
    await supabase.from('chat_messages').delete().eq('room_id', roomId);
    const { error } = await supabase.from('chat_rooms').delete().eq('id', roomId);
    if (error) throw error;
    res.json({ success: true, message: '채팅방이 삭제되었습니다' });
  } catch (error) {
    console.error('[ADMIN] 채팅방 삭제 실패:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 오더에 대해 사업자들에게 알림 발송 (카카오톡 대신 푸시 알림)
router.post('/orders/:orderId/notify', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { orderId } = req.params;
    const { message, targetRegion, targetCategory } = req.body;
    
    console.log(`[ADMIN] 오더 알림 발송: orderId=${orderId}`);
    
    // 1. 오더 정보 조회
    const { data: order, error: orderError } = await supabase
      .from('marketplace_listings')
      .select('*')
      .eq('id', orderId)
      .single();
    
    if (orderError) throw orderError;
    if (!order) {
      return res.status(404).json({ success: false, message: '오더를 찾을 수 없습니다' });
    }
    
    // 2. 알림 받을 사업자 조회 (승인된 사업자만)
    let usersQuery = supabase
      .from('users')
      .select('id, businessname, name, fcm_token')
      .eq('role', 'business')
      .eq('businessstatus', 'approved');
    
    // 지역 필터
    if (targetRegion && order.region) {
      usersQuery = usersQuery.contains('serviceareas', [order.region]);
    }
    
    // 카테고리 필터 (전문 분야)
    if (targetCategory && order.category) {
      usersQuery = usersQuery.contains('specialties', [order.category]);
    }
    
    const { data: users, error: usersError } = await usersQuery;
    
    if (usersError) throw usersError;
    
    if (!users || users.length === 0) {
      return res.json({ 
        success: true, 
        message: '알림을 받을 사업자가 없습니다',
        sent: 0
      });
    }
    
    console.log(`[ADMIN] ${users.length}명의 사업자에게 알림 전송 중...`);
    
    // 3. 각 사업자에게 DB 알림 + FCM 푸시 발송
    const notificationData = {
      title: '🔔 새로운 오더 안내',
      body: message || `새로운 오더가 등록되었습니다: ${order.title}`,
      type: 'admin_order_notification',
      orderid: orderId,
      isread: false,
      createdat: new Date().toISOString(),
    };
    
    let sentCount = 0;
    let failCount = 0;
    
    for (const user of users) {
      try {
        // DB에 알림 저장
        await supabase
          .from('notifications')
          .insert({
            ...notificationData,
            userid: user.id,
          });
        
        // FCM 푸시 알림 전송
        if (user.fcm_token) {
          await sendPushNotification(
            user.id,
            {
              title: notificationData.title,
              body: notificationData.body,
            },
            {
              type: 'admin_order_notification',
              orderId: orderId,
              orderTitle: order.title || '',
            }
          );
        }
        
        sentCount++;
      } catch (err) {
        console.error(`[ADMIN] 사용자 ${user.id}에게 알림 전송 실패:`, err);
        failCount++;
      }
    }
    
    console.log(`[ADMIN] 알림 발송 완료: 성공 ${sentCount}개, 실패 ${failCount}개`);
    
    res.json({
      success: true,
      message: `${sentCount}명의 사업자에게 알림을 전송했습니다`,
      sent: sentCount,
      failed: failCount,
      total: users.length,
    });
  } catch (error) {
    console.error('[ADMIN] 오더 알림 발송 실패:', error);
    res.status(500).json({ 
      success: false, 
      message: '알림 발송에 실패했습니다',
      error: error.message 
    });
  }
});

module.exports = router; 