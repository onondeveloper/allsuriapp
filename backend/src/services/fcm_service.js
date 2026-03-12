const admin = require('firebase-admin');
const { supabase } = require('../config/supabase');

// Firebase Admin 초기화
let firebaseApp = null;

function initializeFirebase() {
  if (firebaseApp) {
    return firebaseApp;
  }

  try {
    // 환경 변수에서 Firebase 서비스 계정 키 로드
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
    
    if (!serviceAccountJson) {
      console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT_KEY 환경 변수가 설정되지 않았습니다.');
      console.warn('   FCM 푸시 알림 기능이 비활성화됩니다.');
      return null;
    }

    const serviceAccount = JSON.parse(serviceAccountJson);

    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log('✅ Firebase Admin SDK 초기화 완료');
    return firebaseApp;
  } catch (error) {
    console.error('❌ Firebase Admin SDK 초기화 실패:', error.message);
    return null;
  }
}

// 앱 시작 시 초기화
initializeFirebase();

/**
 * 단일 사용자에게 FCM 푸시 알림 전송
 * @param {string} userId - Supabase 사용자 ID
 * @param {object} notification - 알림 내용
 * @param {string} notification.title - 알림 제목
 * @param {string} notification.body - 알림 본문
 * @param {object} data - 추가 데이터 (선택)
 * @returns {Promise<boolean>} 성공 여부
 */
async function sendPushNotification(userId, notification, data = {}) {
  try {
    if (!firebaseApp) {
      console.warn('⚠️ Firebase Admin이 초기화되지 않아 푸시 알림을 보낼 수 없습니다.');
      return { success: false, reason: 'FIREBASE_ADMIN_NOT_INITIALIZED' };
    }

    // Supabase에서 사용자의 FCM 토큰 가져오기
    const { data: user, error } = await supabase
      .from('users')
      .select('fcm_token')
      .eq('id', userId)
      .maybeSingle();

    if (error) {
      throw error;
    }

    if (!user || !user.fcm_token) {
      console.log(`ℹ️ 사용자 ${userId}의 FCM 토큰이 없습니다. (푸시 알림 스킵)`);
      return { success: false, reason: 'FCM_TOKEN_NOT_FOUND' };
    }

    const fcmToken = user.fcm_token;

    // FCM 메시지 구성
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        ...data,
        // 타임스탬프 추가
        sentAt: new Date().toISOString(),
      },
      token: fcmToken,
      // Android 설정
      android: {
        priority: 'high',
        notification: {
          channelId: 'allsuri_notifications',
          sound: 'default',
        },
      },
      // iOS 설정
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // FCM 전송
    const response = await admin.messaging().send(message);
    console.log(`✅ FCM 푸시 알림 전송 성공: ${userId}`, response);
    return { success: true };
  } catch (error) {
    // 토큰이 만료되었거나 잘못된 경우
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      console.log(`⚠️ 사용자 ${userId}의 FCM 토큰이 유효하지 않습니다. 토큰을 삭제합니다.`);
      await supabase
        .from('users')
        .update({ fcm_token: null })
        .eq('id', userId);
      return { success: false, reason: 'INVALID_FCM_TOKEN' };
    }
    console.error(`❌ FCM 푸시 알림 전송 실패: ${userId}`, error.message);
    return { success: false, reason: error.message || 'FCM_SEND_FAILED' };
  }
}

/**
 * 여러 사용자에게 FCM 푸시 알림 전송
 * @param {string[]} userIds - Supabase 사용자 ID 배열
 * @param {object} notification - 알림 내용
 * @param {object} data - 추가 데이터 (선택)
 * @returns {Promise<{success: number, failed: number}>} 성공/실패 개수
 */
async function sendPushNotificationToMultiple(userIds, notification, data = {}) {
  const results = await Promise.allSettled(
    userIds.map(userId => sendPushNotification(userId, notification, data))
  );

  const success = results.filter(r => r.status === 'fulfilled' && r.value?.success === true).length;
  const failed = results.length - success;

  console.log(`📊 다중 푸시 알림 전송 결과: 성공 ${success}개, 실패 ${failed}개`);
  return { success, failed };
}

/**
 * 토픽에 FCM 푸시 알림 전송 (예: 모든 사업자, 모든 고객 등)
 * @param {string} topic - 토픽 이름 (예: 'all_business', 'all_customers')
 * @param {object} notification - 알림 내용
 * @param {object} data - 추가 데이터 (선택)
 * @returns {Promise<boolean>} 성공 여부
 */
async function sendPushNotificationToTopic(topic, notification, data = {}) {
  try {
    if (!firebaseApp) {
      console.warn('⚠️ Firebase Admin이 초기화되지 않아 푸시 알림을 보낼 수 없습니다.');
      return false;
    }

    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        ...data,
        sentAt: new Date().toISOString(),
      },
      topic: topic,
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ 토픽 '${topic}'에 FCM 푸시 알림 전송 성공`, response);
    return true;
  } catch (error) {
    console.error(`❌ 토픽 '${topic}'에 FCM 푸시 알림 전송 실패:`, error.message);
    return false;
  }
}

module.exports = {
  initializeFirebase,
  sendPushNotification,
  sendPushNotificationToMultiple,
  sendPushNotificationToTopic,
};

