const mongoose = require('mongoose');

const notificationSettingsSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    settings: {
      new_estimate: {
        type: Boolean,
        default: true,
      },
      estimate_accepted: {
        type: Boolean,
        default: true,
      },
      estimate_rejected: {
        type: Boolean,
        default: true,
      },
      order_status_changed: {
        type: Boolean,
        default: true,
      },
      order_completed: {
        type: Boolean,
        default: true,
      },
      chat_message: {
        type: Boolean,
        default: true,
      },
    },
    fcmTokens: [{
      token: {
        type: String,
        required: true,
      },
      device: {
        type: String,
        required: true,
      },
      lastUsed: {
        type: Date,
        default: Date.now,
      },
    }],
  },
  { timestamps: true }
);

// 인덱스 생성
notificationSettingsSchema.index({ userId: 1 });
notificationSettingsSchema.index({ 'fcmTokens.token': 1 });

const NotificationSettings = mongoose.model('NotificationSettings', notificationSettingsSchema);

module.exports = NotificationSettings; 