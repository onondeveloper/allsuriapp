import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class Announcement {
  final String id;
  final String message;
  final String bgColor;
  final String textColor;
  final bool isDismissible;
  final DateTime? startAt;
  final DateTime? endAt;

  const Announcement({
    required this.id,
    required this.message,
    required this.bgColor,
    required this.textColor,
    required this.isDismissible,
    this.startAt,
    this.endAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> m) {
    return Announcement(
      id: m['id']?.toString() ?? '',
      message: m['message']?.toString() ?? '',
      bgColor: m['bg_color']?.toString() ?? '#1E3A8A',
      textColor: m['text_color']?.toString() ?? '#FFFFFF',
      isDismissible: m['is_dismissible'] == true,
      startAt: m['start_at'] != null ? DateTime.tryParse(m['start_at']) : null,
      endAt: m['end_at'] != null ? DateTime.tryParse(m['end_at']) : null,
    );
  }
}

class AnnouncementService {
  final _sb = Supabase.instance.client;

  /// 현재 활성화된 공지 배너 목록을 가져옵니다.
  Future<List<Announcement>> getActiveAnnouncements() async {
    try {
      final now = DateTime.now().toUtc();
      final data = await _sb
          .from('announcements')
          .select('id, message, bg_color, text_color, is_dismissible, start_at, end_at')
          .eq('is_active', true)
          .or('start_at.is.null,start_at.lte.${now.toIso8601String()}')
          .or('end_at.is.null,end_at.gte.${now.toIso8601String()}')
          .order('sort_order', ascending: true)
          .limit(5);

      return (data as List)
          .map((e) => Announcement.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      // 테이블 미생성 시 조용히 빈 목록 반환 (앱 동작에 영향 없음)
      // 해결: Supabase SQL Editor에서 database/create_announcements.sql 실행
      if (e.toString().contains('announcements')) {
        debugPrint('ℹ️ announcements 테이블 없음 - Supabase에서 create_announcements.sql 실행 필요');
      } else {
        debugPrint('AnnouncementService 오류: $e');
      }
      return [];
    }
  }
}
