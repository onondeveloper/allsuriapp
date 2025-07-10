const express = require('express');
const router = express.Router();

// 기본 주문 라우트
router.get('/', (req, res) => {
  res.json({ message: 'Orders endpoint' });
});

module.exports = router; 