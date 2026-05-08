import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart' as app_models;
import '../screens/business/business_profile_screen.dart';
import '../services/auth_service.dart';

/// 사업자 활동(오더 생성, 입찰, 견적, 공사 등록) 전 진위확인 상태를 점검한다.
///
/// 분기:
/// - 인증 완료(verified): 그대로 통과
/// - 유예 기간 중: 1회성 안내 다이얼로그 표시 후 통과 (남은 시간 표시)
/// - 유예 만료/실패/휴폐업: 차단 다이얼로그 + 프로필 이동 옵션
/// - 비사업자: false 반환 (호출 측에서 별도 처리)
class BusinessVerifyGuard {
  /// 현재 사용자가 사업자 활동을 수행 가능한지 확인한다.
  /// 통과 가능하면 true, 차단되었으면 false를 반환한다.
  static Future<bool> ensure(BuildContext context, {String action = '이 작업'}) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      _snack(context, '로그인이 필요합니다.');
      return false;
    }
    if (user.role != 'business') {
      _snack(context, '사업자 회원만 이용할 수 있습니다.');
      return false;
    }

    // 관리자 화이트리스트 우회 (사업자번호 보유 여부와 무관)
    if (user.businessVerifyBypass) return true;

    if (user.businessVerifyStatus == app_models.BusinessVerifyStatus.verified &&
        user.hasBusinessNumber) {
      return true;
    }

    // 사업자번호가 등록되어 있어야 grace 통과 가능
    if (user.isInGracePeriod && user.hasBusinessNumber) {
      final remaining = user.graceRemaining;
      final remainingText = _humanizeRemaining(remaining);
      final continueAnyway = await _showGraceDialog(context, action, remainingText);
      return continueAnyway;
    }

    await _showBlockedDialog(context, user, action);
    return false;
  }

  /// 인증 안내 다이얼로그만 노출 (액션 없이 안내 용도)
  static Future<void> showVerifyPrompt(BuildContext context) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    await _showBlockedDialog(context, user, '사업자 활동');
  }

  static String _humanizeRemaining(Duration? d) {
    if (d == null) return '';
    if (d.inDays >= 1) return '${d.inDays}일';
    if (d.inHours >= 1) return '${d.inHours}시간';
    if (d.inMinutes >= 1) return '${d.inMinutes}분';
    return '잠시';
  }

  static Future<bool> _showGraceDialog(
    BuildContext context,
    String action,
    String remainingText,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.access_time_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('사업자 인증 유예 안내'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              remainingText.isNotEmpty
                  ? '인증 만료까지 약 $remainingText 남았습니다.'
                  : '곧 사업자 인증이 필요합니다.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              '유예 기간이 지나면 $action을(를) 진행할 수 없게 됩니다.\n'
              '지금 사업자등록 진위확인을 완료해 주세요.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('나중에 하기'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _goToBusinessProfile(context);
            },
            child: const Text('지금 인증하기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _showBlockedDialog(
    BuildContext context,
    app_models.User user,
    String action,
  ) async {
    final reason = _reasonText(user);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text('사업자 인증이 필요합니다'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              '국세청 사업자등록 진위확인을 완료해야 $action이(가) 가능합니다.',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.verified_outlined),
            label: const Text('인증하러 가기'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _goToBusinessProfile(context);
            },
          ),
        ],
      ),
    );
  }

  static String _reasonText(app_models.User user) {
    if (!user.hasBusinessNumber) {
      return '사업자등록번호가 등록되어 있지 않습니다.';
    }
    switch (user.businessVerifyStatus) {
      case app_models.BusinessVerifyStatus.failed:
        return '진위확인에 실패한 이력이 있습니다.';
      case app_models.BusinessVerifyStatus.closed:
        return '사업자 상태가 휴/폐업으로 조회되었습니다.';
      case app_models.BusinessVerifyStatus.unverified:
      case app_models.BusinessVerifyStatus.verified:
        return '아직 사업자등록 진위확인이 완료되지 않았습니다.';
    }
  }

  static void _goToBusinessProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
