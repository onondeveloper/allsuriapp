import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart' as app_models;
import '../screens/business/business_profile_screen.dart';
import '../services/auth_service.dart';

/// 사업자 활동(오더 생성, 입찰, 견적, 공사 등록) 전 자격 점검.
///
/// 2026-05 정책 완화:
/// - 관리자 우회(bypass=TRUE): 즉시 통과
/// - 사업자번호 보유: 진위확인 결과 무관하게 통과
///   (국세청 API의 false negative 이슈 대응; verified 가 아니어도 활동 허용)
/// - 사업자번호 미등록: 안내 다이얼로그 + 프로필 이동 후 차단
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

    if (user.businessVerifyBypass) return true;
    if (user.hasBusinessNumber) return true;

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

  static Future<void> _showBlockedDialog(
    BuildContext context,
    app_models.User user,
    String action,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.business_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text('사업자등록번호가 필요합니다'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '사업자등록번호가 등록되어 있지 않습니다.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              '사업자 프로필에서 10자리 사업자등록번호를 입력해 주시면 '
              '오더 등록·입찰·낙찰 기능을 바로 사용하실 수 있습니다.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('사업자번호 입력하기'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _goToBusinessProfile(context);
            },
          ),
        ],
      ),
    );
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
