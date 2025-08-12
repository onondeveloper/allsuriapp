require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const orderRoutes = require('./routes/orders');
const notificationRoutes = require('./routes/notifications');
const adminRoutes = require('./routes/admin');

const app = express();

// Middleware
app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);

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
  app.listen(port, () => {
    console.log(`서버가 포트 ${port}에서 실행 중입니다`);
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