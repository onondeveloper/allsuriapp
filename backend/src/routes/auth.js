const express = require('express');
const router = express.Router();

// 기본 인증 라우트
router.post('/login', (req, res) => {
  res.json({ message: 'Login endpoint' });
});

router.post('/register', (req, res) => {
  res.json({ message: 'Register endpoint' });
});

module.exports = router; 