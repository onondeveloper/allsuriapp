require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const orderRoutes = require('./routes/orders');
const notificationRoutes = require('./routes/notifications');
const adminRoutes = require('./routes/admin');
const marketRoutes = require('./routes/market');
const aiRoutes = require('./routes/ai');
let adsPublicRoutes;

const app = express();

// Middleware
app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));

// Basic Auth for Admin UI (protects '/', '/admin', and static admin assets)
const basicAuth = (req, res, next) => {
  const { ADMIN_USER, ADMIN_PASS } = process.env;
  // If not configured, skip protection (for local/dev by default)
  if (!ADMIN_USER || !ADMIN_PASS) return next();

  // Only require auth for read-like access (GET/HEAD) to root/admin UI endpoints
  const isAdminUiPath = req.path === '/' || req.path === '/admin' || req.path.startsWith('/admin/');
  const isReadLike = req.method === 'GET' || req.method === 'HEAD';
  if (!isAdminUiPath || !isReadLike) return next();

  const header = req.headers['authorization'];
  if (!header || !header.startsWith('Basic ')) {
    res.set('WWW-Authenticate', 'Basic realm="Allsuri Admin"');
    return res.status(401).send('Authentication required');
  }
  try {
    const base64 = header.split(' ')[1];
    const decoded = Buffer.from(base64, 'base64').toString('utf8');
    const sep = decoded.indexOf(':');
    const user = sep >= 0 ? decoded.slice(0, sep) : '';
    const pass = sep >= 0 ? decoded.slice(sep + 1) : '';
    if (user === ADMIN_USER && pass === ADMIN_PASS) return next();
  } catch (e) {
    // fallthrough to 401 below
  }
  res.set('WWW-Authenticate', 'Basic realm="Allsuri Admin"');
  return res.status(401).send('Invalid credentials');
};

// 정적 파일 제공 (관리자 대시보드) - 보호 적용 + 캐시 비활성화
app.use('/admin', basicAuth, express.static(path.join(__dirname, '..', 'public'), {
  setHeaders: (res, path) => {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');
  }
}));
// 광고 정적 파일 제공 (광고 전용 경로)
app.use('/ads', express.static(path.join(__dirname, '..', 'public', 'ads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/market', marketRoutes);
app.use('/api/ai', aiRoutes);
try {
  adsPublicRoutes = require('./routes/ads_public');
  app.use('/api/ads', adsPublicRoutes);
} catch (e) {
  console.warn('ads_public route not loaded:', e?.message);
}

// 루트 및 관리자 대시보드 라우트 (보호 적용)
app.get('/', basicAuth, (req, res) => {
  // 루트 접근 시 관리자 페이지로 이동 (동일 보호)
  res.redirect('/admin');
});

app.get('/admin', basicAuth, (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'admin.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || '서버 오류가 발생했습니다',
  });
});

// Database connection (optional)
const startServer = () => {
  const port = process.env.PORT || 3000;
  const host = process.env.HOST || '0.0.0.0';
  app.listen(port, host, () => {
    console.log(`서버가 ${host}:${port} 에서 실행 중입니다`);
  });
};

if (process.env.MONGODB_URI) {
  mongoose
    .connect(process.env.MONGODB_URI)
    .then(() => {
      console.log('MongoDB에 연결되었습니다');
      startServer();
    })
    .catch((err) => {
      console.error('MongoDB 연결 오류:', err);
      console.warn('MongoDB 연결 없이 서버를 시작합니다(관리자 API는 Supabase 사용).');
      startServer();
    });
} else {
  console.warn('MONGODB_URI가 없어 MongoDB 연결 없이 서버를 시작합니다.');
  startServer();
}