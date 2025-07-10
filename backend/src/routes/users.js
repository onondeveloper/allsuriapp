const express = require('express');
const router = express.Router();

// 기본 사용자 라우트
router.get('/', (req, res) => {
  res.json({ message: 'Users endpoint' });
});

module.exports = router; 