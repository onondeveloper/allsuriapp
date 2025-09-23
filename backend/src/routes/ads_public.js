const express = require('express');
const router = express.Router();
const { supabase } = require('../config/supabase');

// Public: list active ads (for app)
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('ads')
      .select('*')
      .eq('status', 'active')
      .order('priority', { ascending: false })
      .order('createdat', { ascending: false });
    if (error) throw error;
    res.json(data || []);
  } catch (e) {
    res.status(500).json({ message: '광고 조회 실패' });
  }
});

// simple impression logging
router.post('/:id/impression', async (req, res) => {
  try {
    const adId = req.params.id;
    await supabase.from('ads_events').insert({ ad_id: adId, type: 'impression', createdat: new Date().toISOString() });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: '노출 기록 실패' });
  }
});

// simple click logging
router.post('/:id/click', async (req, res) => {
  try {
    const adId = req.params.id;
    await supabase.from('ads_events').insert({ ad_id: adId, type: 'click', createdat: new Date().toISOString() });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: '클릭 기록 실패' });
  }
});

module.exports = router;
