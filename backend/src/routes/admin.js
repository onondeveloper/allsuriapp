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
    const payload = req.body || {};
    payload.createdat = new Date().toISOString();
    const { data, error } = await supabase.from('ads').insert(payload).select('*').single();
    if (error) throw error;
    res.status(201).json(data);
  } catch (e) {
    res.status(500).json({ message: '광고 생성 실패' });
  }
});

router.put('/ads/:id', requireRole('developer', 'staff'), async (req, res) => {
  try {
    const { data, error } = await supabase.from('ads').update(req.body || {}).eq('id', req.params.id).select('*').maybeSingle();
    if (error) throw error;
    res.json(data);
  } catch (e) {
    res.status(500).json({ message: '광고 업데이트 실패' });
  }
});

router.delete('/ads/:id', requireRole('developer'), async (req, res) => {
  try {
    const { error } = await supabase.from('ads').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: '광고 삭제 완료' });
  } catch (e) {
    res.status(500).json({ message: '광고 삭제 실패' });
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
    
    // 완료된 견적의 총 금액
    const completed = estimates.filter(e => e.status === 'completed');
    const totalEstimateAmount = completed.reduce((sum, e) => sum + getAmount(e), 0);
    
    // 완료된 견적의 5% 수익
    const totalRevenue = totalEstimateAmount * 0.05;
    
    const averageEstimateAmount = completed.length > 0
      ? totalEstimateAmount / completed.length
      : 0;

    // 주문 통계도 추가
    const ordersResult = await supabase
      .from('orders')
      .select('id, status, createdat');
    
    orders = ordersResult.data;
    
    if (ordersResult.error) {
      console.error('[ADMIN DASHBOARD] Orders error:', ordersResult.error);
      // 주문 에러는 치명적이지 않으므로 계속 진행
    }

    const totalOrders = (orders || []).length;

    // Call 공사 통계 (jobs 테이블)
    let jobs;
    const jobsResult = await supabase
      .from('jobs')
      .select('id, status, assigned_business_id, createdat');
    
    jobs = jobsResult.data;
    
    if (jobsResult.error) {
      console.error('[ADMIN DASHBOARD] Jobs error:', jobsResult.error);
      // Jobs 에러는 치명적이지 않으므로 계속 진행
    }

    const totalJobs = (jobs || []).length;
    // 대기 중: assigned_business_id가 null인 경우 (아직 다른 사업자가 가져가지 않음)
    const pendingJobs = (jobs || []).filter(j => !j.assigned_business_id && j.status !== 'completed' && j.status !== 'cancelled').length;
    // 완료: assigned_business_id가 있는 경우 (다른 사업자가 가져간 경우)
    const completedJobs = (jobs || []).filter(j => j.assigned_business_id !== null).length;

    const dashboardData = {
      // totalUsers 제거
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
    const { error } = await supabase.from('users').delete().eq('id', req.params.id);
    if (error) throw error;
    res.json({ success: true, message: '사용자 삭제 완료' });
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

module.exports = router; 