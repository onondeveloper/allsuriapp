const express = require('express');
const router = express.Router();
const AdminMessage = require('../models/admin-message');
const AdminStatistics = require('../models/admin-statistics');
// const User = require('../models/user');
// const Estimate = require('../models/estimate');
// const Order = require('../models/order');
const { supabase } = require('../config/supabase');

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
  try {
    const { data: users, error: usersErr } = await supabase.from('users').select('id, role');
    if (usersErr) throw usersErr;
    const totalUsers = users.length;
    const totalBusinessUsers = users.filter(u => u.role === 'business').length;
    const totalCustomers = users.filter(u => u.role === 'customer').length;

    // 대시보드는 사업자 제출 견적(estimates 테이블)을 기준으로 계산
    const { data: estimatesAll, error: estimatesErr } = await supabase
      .from('estimates')
      .select('id, status, amount');
    if (estimatesErr) throw estimatesErr;
    const totalEstimates = (estimatesAll || []).length;
    const pendingEstimates = (estimatesAll || []).filter(e => e.status === 'pending').length;
    const approvedEstimates = (estimatesAll || []).filter(e => e.status === 'approved').length;
    const completedEstimates = (estimatesAll || []).filter(e => e.status === 'completed').length;
    const inProgressEstimates = (estimatesAll || []).filter(e => e.status === 'in_progress').length;
    const awardedEstimates = (estimatesAll || []).filter(e => e.status === 'awarded').length;
    const transferredEstimates = (estimatesAll || []).filter(e => e.status === 'transferred').length;

    const completed = (estimatesAll || []).filter(e => e.status === 'completed');
    const totalRevenue = completed.reduce((sum, e) => sum + ((e.amount || 0) * 0.05), 0);
    const averageEstimateAmount = completed.length > 0 ? completed.reduce((s, e) => s + (e.amount || 0), 0) / completed.length : 0;

    res.json({
      totalUsers,
      totalBusinessUsers,
      totalCustomers,
      totalEstimates,
      pendingEstimates,
      approvedEstimates,
      completedEstimates,
      inProgressEstimates,
      awardedEstimates,
      transferredEstimates,
      totalRevenue,
      averageEstimateAmount,
    });
  } catch (error) {
    res.status(500).json({ message: '대시보드 데이터 조회 실패' });
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
    const { data, error } = await supabase.from('users').update({ businessStatus: status }).eq('id', req.params.id).select().maybeSingle();
    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(500).json({ message: '사용자 상태 업데이트 실패' });
  }
});

router.delete('/users/:id', async (req, res) => {
  try {
    const { error } = await supabase.from('users').update({ role: 'customer', businessStatus: 'rejected' }).eq('id', req.params.id);
    if (error) throw error;
    res.json({ message: '사용자 처리 완료(고객 강등/거절)' });
  } catch (error) {
    res.status(500).json({ message: '사용자 삭제 실패' });
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