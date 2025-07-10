const mongoose = require('mongoose');

const businessBillingSchema = new mongoose.Schema({
  businessId: {
    type: String,
    required: true,
  },
  businessName: {
    type: String,
    required: true,
  },
  region: {
    type: String,
    required: true,
  },
  bidCount: {
    type: Number,
    default: 0,
  },
  winCount: {
    type: Number,
    default: 0,
  },
  winRate: {
    type: Number,
    default: 0,
  },
  monthlyRevenue: {
    type: Number,
    default: 0,
  },
  services: [{
    type: String,
  }],
  lastActivity: {
    type: Date,
    default: Date.now,
  },
});

const adminStatisticsSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true,
    default: Date.now,
  },
  totalUsers: {
    type: Number,
    default: 0,
  },
  totalBusinessUsers: {
    type: Number,
    default: 0,
  },
  totalCustomers: {
    type: Number,
    default: 0,
  },
  totalEstimates: {
    type: Number,
    default: 0,
  },
  completedEstimates: {
    type: Number,
    default: 0,
  },
  pendingEstimates: {
    type: Number,
    default: 0,
  },
  totalRevenue: {
    type: Number,
    default: 0,
  },
  averageEstimateAmount: {
    type: Number,
    default: 0,
  },
  estimatesByRegion: {
    type: Map,
    of: Number,
    default: {},
  },
  estimatesByService: {
    type: Map,
    of: Number,
    default: {},
  },
  businessBillings: [businessBillingSchema],
}, {
  timestamps: true,
});

module.exports = mongoose.model('AdminStatistics', adminStatisticsSchema); 