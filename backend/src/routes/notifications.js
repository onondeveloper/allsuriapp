const express = require('express');
const { body, query } = require('express-validator');
const auth = require('../middleware/auth');
const validate = require('../middleware/validate');
const notificationService = require('../services/notification-service');

const router = express.Router();

// 알림 목록 조회
router.get(
  '/',
  auth,
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
  ],
  validate,
  async (req, res) => {
    try {
      const { page = 1, limit = 20 } = req.query;
      const result = await notificationService.getNotifications(
        req.user._id,
        parseInt(page),
        parseInt(limit)
      );
      res.json(result);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// 알림 읽음 처리
router.patch(
  '/:id/read',
  auth,
  async (req, res) => {
    try {
      const notification = await notificationService.markAsRead(
        req.user._id,
        req.params.id
      );
      if (!notification) {
        return res.status(404).json({ message: '알림을 찾을 수 없습니다' });
      }
      res.json(notification);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// 모든 알림 읽음 처리
router.patch(
  '/read-all',
  auth,
  async (req, res) => {
    try {
      await notificationService.markAllAsRead(req.user._id);
      res.json({ message: '모든 알림이 읽음 처리되었습니다' });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// FCM 토큰 등록/업데이트
router.post(
  '/fcm-token',
  auth,
  [
    body('token').notEmpty().withMessage('토큰은 필수입니다'),
    body('device').notEmpty().withMessage('디바이스 정보는 필수입니다'),
  ],
  validate,
  async (req, res) => {
    try {
      const { token, device } = req.body;
      const settings = await notificationService.updateFCMToken(
        req.user._id,
        token,
        device
      );
      res.json(settings);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// FCM 토큰 삭제
router.delete(
  '/fcm-token',
  auth,
  [
    body('token').notEmpty().withMessage('토큰은 필수입니다'),
  ],
  validate,
  async (req, res) => {
    try {
      const { token } = req.body;
      await notificationService.deleteFCMToken(req.user._id, token);
      res.json({ message: '토큰이 삭제되었습니다' });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// 알림 설정 조회
router.get(
  '/settings',
  auth,
  async (req, res) => {
    try {
      const settings = await notificationService.getNotificationSettings(req.user._id);
      res.json(settings);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

// 알림 설정 업데이트
router.put(
  '/settings',
  auth,
  [
    body('new_estimate').optional().isBoolean(),
    body('estimate_accepted').optional().isBoolean(),
    body('estimate_rejected').optional().isBoolean(),
    body('order_status_changed').optional().isBoolean(),
    body('order_completed').optional().isBoolean(),
    body('chat_message').optional().isBoolean(),
  ],
  validate,
  async (req, res) => {
    try {
      const settings = await notificationService.updateNotificationSettings(
        req.user._id,
        req.body
      );
      res.json(settings);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  }
);

module.exports = router; 