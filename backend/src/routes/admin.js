const express = require('express');
const router = express.Router();
const AdminMessage = require('../models/admin-message');
const AdminStatistics = require('../models/admin-statistics');
const User = require('../models/user');
const Estimate = require('../models/estimate');
const Order = require('../models/order');

// 미들웨어: 관리자 권한 확인
const requireAdmin = async (req, res, next) => {
  try {
    // 실제 구현에서는 JWT 토큰을 확인하여 관리자 권한을 검증
    // 여기서는 간단히 헤더에서 admin-token을 확인
    const adminToken = req.headers['admin-token'];
    if (!adminToken) {
      return res.status(401).json({ message: '관리자 권한이 필요합니다' });
    }
    next();
  } catch (error) {
    res.status(401).json({ message: '인증 실패' });
  }
};

// 모든 라우트에 관리자 권한 미들웨어 적용
router.use(requireAdmin);

// 대시보드 데이터
router.get('/dashboard', async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const totalBusinessUsers = await User.countDocuments({ role: 'business' });
    const totalCustomers = await User.countDocuments({ role: 'customer' });
    const totalEstimates = await Estimate.countDocuments();
    const completedEstimates = await Estimate.countDocuments({ status: 'completed' });
    const pendingEstimates = await Estimate.countDocuments({ status: 'pending' });

    // 수익 계산 (견적 금액의 5% 수수료 가정)
    const estimates = await Estimate.find({ status: 'completed' });
    const totalRevenue = estimates.reduce((sum, estimate) => sum + (estimate.amount * 0.05), 0);
    const averageEstimateAmount = estimates.length > 0 ? estimates.reduce((sum, estimate) => sum + estimate.amount, 0) / estimates.length : 0;

    res.json({
      totalUsers,
      totalBusinessUsers,
      totalCustomers,
      totalEstimates,
      completedEstimates,
      pendingEstimates,
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
    const users = await User.find().sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: '사용자 조회 실패' });
  }
});

router.patch('/users/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: '사용자 상태 업데이트 실패' });
  }
});

router.delete('/users/:id', async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: '사용자 삭제 완료' });
  } catch (error) {
    res.status(500).json({ message: '사용자 삭제 실패' });
  }
});

// 사용자 검색
router.get('/users/search', async (req, res) => {
  try {
    const { q, type, status } = req.query;
    let query = {};

    if (q) {
      query.$or = [
        { name: { $regex: q, $options: 'i' } },
        { email: { $regex: q, $options: 'i' } },
      ];
    }

    if (type && type !== '전체') {
      query.role = type === '사업자' ? 'business' : 'customer';
    }

    if (status && status !== '전체') {
      query.status = status;
    }

    const users = await User.find(query).sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: '사용자 검색 실패' });
  }
});

// 견적 관리
router.get('/estimates', async (req, res) => {
  try {
    const estimates = await Estimate.find()
      .populate('customerId', 'name email')
      .populate('businessId', 'name email')
      .sort({ createdAt: -1 });
    res.json(estimates);
  } catch (error) {
    res.status(500).json({ message: '견적 조회 실패' });
  }
});

router.patch('/estimates/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const estimate = await Estimate.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );
    res.json(estimate);
  } catch (error) {
    res.status(500).json({ message: '견적 상태 업데이트 실패' });
  }
});

// 견적 검색
router.get('/estimates/search', async (req, res) => {
  try {
    const { q, status } = req.query;
    let query = {};

    if (q) {
      query.$or = [
        { title: { $regex: q, $options: 'i' } },
        { description: { $regex: q, $options: 'i' } },
      ];
    }

    if (status && status !== '전체') {
      query.status = status;
    }

    const estimates = await Estimate.find(query)
      .populate('customerId', 'name email')
      .populate('businessId', 'name email')
      .sort({ createdAt: -1 });
    res.json(estimates);
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