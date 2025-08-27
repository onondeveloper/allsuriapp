import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class PaymentService extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  // Stub 결제: 실제 결제 게이트웨이 연동 전까지 성공으로 처리
  Future<bool> chargeTransferFee({
    required String payerBusinessId,
    required String payeeBusinessId,
    required double awardedAmount,
  }) async {
    // 5% 수수료
    final double fee = (awardedAmount * 0.05);
    // TODO: 실제 PG 연동 (아임포트/토스/Stripe 등)
    await Future.delayed(const Duration(milliseconds: 500));
    await _notificationService.sendNotification(
      userId: payerBusinessId,
      title: '이관 수수료 결제',
      body: '이관 수수료 ₩${fee.toStringAsFixed(0)} 결제(가상)가 처리되었습니다.',
      type: 'payment',
    );
    await _notificationService.sendNotification(
      userId: payeeBusinessId,
      title: '이관 수수료 수령',
      body: '이관 수수료 ₩${fee.toStringAsFixed(0)} 수령(가상) 대기 중입니다.',
      type: 'payment',
    );
    return true;
  }

  // B2C 낙찰 시 플랫폼 수수료(5%) 가상 정산 알림
  Future<void> notifyB2cAwardFee({
    required String businessId,
    required double awardedAmount,
  }) async {
    final double platformFee = (awardedAmount * 0.05);
    await _notificationService.sendNotification(
      userId: businessId,
      title: '플랫폼 수수료 정산 안내',
      body: 'B2C 낙찰 수수료(5%) ₩${platformFee.toStringAsFixed(0)}가 발생했습니다. (가상)',
      type: 'settlement',
    );
  }

  // B2B 이관 시 플랫폼 수수료(3%) 가상 정산 알림
  Future<void> notifyB2bPlatformFee({
    required String assigneeBusinessId,
    required double awardedAmount,
  }) async {
    final double platformFee = (awardedAmount * 0.03);
    await _notificationService.sendNotification(
      userId: assigneeBusinessId,
      title: '플랫폼 수수료 정산 안내',
      body: 'B2B 이관 수수료(3%) ₩${platformFee.toStringAsFixed(0)}가 발생했습니다. (가상)',
      type: 'settlement',
    );
  }

  // Firestore 제거: Supabase Notifications 사용으로 대체
}


