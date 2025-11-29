import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ad.dart';

class AdService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<Ad>> getActiveAds() async {
    try {
      final response = await _sb
          .from('ads')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);
      return data.map((json) => Ad.fromJson(json)).toList();
    } catch (e) {
      print('❌ [AdService] 광고 로드 실패: $e');
      return [];
    }
  }
}

