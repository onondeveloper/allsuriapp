const mongoose = require('mongoose');

const adminMessageSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  content: {
    type: String,
    required: true,
  },
  recipientType: {
    type: String,
    enum: ['all', 'business', 'customer', 'specific'],
    required: true,
  },
  recipients: [{
    type: String,
  }],
  senderId: {
    type: String,
    required: true,
  },
  senderName: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['draft', 'sent', 'failed'],
    default: 'draft',
  },
  readCount: {
    type: Number,
    default: 0,
  },
  totalRecipients: {
    type: Number,
    default: 0,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('AdminMessage', adminMessageSchema); 