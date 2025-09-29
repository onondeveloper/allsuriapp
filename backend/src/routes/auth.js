const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const fetch = require('node-fetch');
const { supabase } = require('../config/supabase');

// 기본 인증 라우트
router.post('/login', (req, res) => {
  res.json({ message: 'Login endpoint' });
});

router.post('/register', (req, res) => {
  res.json({ message: 'Register endpoint' });
});

// Kakao 로그인: 클라이언트가 전달한 access_token 검증 → 사용자 upsert → 백엔드 세션 발급
router.post('/kakao/login', async (req, res) => {
  try {
    const { access_token } = req.body || {};
    if (!access_token) return res.status(400).json({ message: 'access_token is required' });

    // Kakao 사용자 정보 조회
    const kakaoRes = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${access_token}` },
    });
    if (!kakaoRes.ok) {
      const text = await kakaoRes.text();
      return res.status(401).json({ message: 'Invalid Kakao token', detail: text });
    }
    const kakao = await kakaoRes.json();
    const kakaoId = String(kakao.id);
    const profile = kakao.kakao_account || {};
    const email = profile.email || '';
    const name = (profile.profile && profile.profile.nickname) || '카카오 사용자';

    // Supabase users 테이블에 upsert (카카오 id를 id로 사용하지 않고, 별도 매핑 컬럼 사용 권장)
    // 여기서는 email이 있으면 email로, 없으면 kakao:${kakaoId} 의 가상 이메일로 식별
    const userId = `kakao:${kakaoId}`;
    const userRow = {
      id: userId,
      email: email || `${userId}@example.local`,
      name,
      role: 'customer',
      createdAt: new Date().toISOString(),
    };

    const { error: upsertErr } = await supabase.from('users').upsert(userRow, { onConflict: 'id' });
    if (upsertErr) throw upsertErr;

    // 백엔드 세션 토큰 발급
    const secret = process.env.JWT_SECRET || 'change_me';
    const token = jwt.sign({ sub: userId, provider: 'kakao' }, secret, { expiresIn: '30d' });

    res.json({ ok: true, token, user: { id: userId, name, email } });
  } catch (e) {
    console.error('Kakao login error:', e);
    res.status(500).json({ message: 'Kakao login failed' });
  }
});

module.exports = router; 