const express = require('express');
const router = express.Router();
const { supabase } = require('../config/supabase');
const { sendPushNotification, sendPushNotificationToMultiple } = require('../services/fcm_service');

// 인증 미들웨어 (간단한 Bearer 토큰 체크)
const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: '인증이 필요합니다' });
  }
  // 실제로는 JWT 토큰 검증 등을 수행해야 함
  next();
};

/**
 * POST /api/notifications/send-push
 * 단일 사용자에게 FCM 푸시 알림 전송
 * 
 * Body:
 * {
 *   "userId": "kakao:123",
 *   "notification": {
 *     "title": "제목",
 *     "body": "내용"
 *   },
 *   "data": {
 *     "type": "new_estimate",
 *     "estimateId": "123"
 *   }
 * }
 */
router.post('/send-push', requireAuth, async (req, res) => {
  try {
    const { userId, notification, data } = req.body;

    if (!userId || !notification || !notification.title || !notification.body) {
      return res.status(400).json({
        success: false,
        message: 'userId, notification.title, notification.body는 필수입니다.',
      });
    }

    const success = await sendPushNotification(userId, notification, data || {});

    if (success) {
      return res.json({
        success: true,
        message: '푸시 알림이 전송되었습니다.',
      });
    } else {
      return res.status(500).json({
        success: false,
        message: '푸시 알림 전송에 실패했습니다.',
      });
    }
  } catch (error) {
    console.error('[PUSH] 푸시 알림 전송 오류:', error);
    return res.status(500).json({
      success: false,
      message: '푸시 알림 전송 중 오류가 발생했습니다.',
      error: error.message,
    });
  }
});

/**
 * POST /api/notifications/send-push-multiple
 * 여러 사용자에게 FCM 푸시 알림 전송
 * 
 * Body:
 * {
 *   "userIds": ["kakao:123", "kakao:456"],
 *   "notification": {
 *     "title": "제목",
 *     "body": "내용"
 *   },
 *   "data": {
 *     "type": "announcement"
 *   }
 * }
 */
router.post('/send-push-multiple', requireAuth, async (req, res) => {
  try {
    const { userIds, notification, data } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'userIds는 비어 있지 않은 배열이어야 합니다.',
      });
    }

    if (!notification || !notification.title || !notification.body) {
      return res.status(400).json({
        success: false,
        message: 'notification.title, notification.body는 필수입니다.',
      });
    }

    const result = await sendPushNotificationToMultiple(userIds, notification, data || {});

    return res.json({
      success: true,
      message: `푸시 알림 전송 완료: 성공 ${result.success}개, 실패 ${result.failed}개`,
      result,
    });
  } catch (error) {
    console.error('[PUSH] 다중 푸시 알림 전송 오류:', error);
    return res.status(500).json({
      success: false,
      message: '푸시 알림 전송 중 오류가 발생했습니다.',
      error: error.message,
    });
  }
});

/**
 * GET /api/notifications
 * 사용자의 알림 목록 가져오기
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const userId = req.query.userId;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'userId는 필수입니다.',
      });
    }

    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('userid', userId)
      .order('createdat', { ascending: false });

    if (error) {
      throw error;
    }

    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('[NOTIFICATIONS] 알림 목록 조회 오류:', error);
    return res.status(500).json({
      success: false,
      message: '알림 목록 조회 중 오류가 발생했습니다.',
      error: error.message,
    });
  }
});

/**
 * PATCH /api/notifications/:id/read
 * 알림을 읽음으로 표시
 */
router.patch('/:id/read', requireAuth, async (req, res) => {
  try {
    const notificationId = req.params.id;

    const { data, error } = await supabase
      .from('notifications')
      .update({ isread: true })
      .eq('id', notificationId)
      .select()
      .maybeSingle();

    if (error) {
      throw error;
    }

    return res.json({
      success: true,
      data,
    });
  } catch (error) {
    console.error('[NOTIFICATIONS] 알림 읽음 표시 오류:', error);
    return res.status(500).json({
      success: false,
      message: '알림 읽음 표시 중 오류가 발생했습니다.',
      error: error.message,
    });
  }
});

module.exports = router;
