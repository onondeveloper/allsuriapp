import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listListings({
    String status = 'open',
    String? region,
    String? category,
    bool throwOnError = false,
    String? postedBy,
    String? claimedBy,
  }) async {
    debugPrint('listListings 시작: status=$status, region=$region, category=$category');
    try {
      // Join jobs to get commission_rate for display
      var query = _sb.from('marketplace_listings').select('*, jobs(commission_rate)');
      debugPrint('listListings: 기본 쿼리 생성');
      
      if (status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
        debugPrint('listListings: status 필터 추가 - $status');
      } else if (status == 'all') { // 'all' 상태 처리 추가
        query = query.inFilter('status', ['open', 'withdrawn', 'created']);
        debugPrint('listListings: \'all\' 상태 필터 추가 - [open, withdrawn, created]');
      }
      if (region != null && region.isNotEmpty) {
        query = query.eq('region', region);
        debugPrint('listListings: region 필터 추가 - $region');
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
        debugPrint('listListings: category 필터 추가 - $category');
      }
      if (postedBy != null && postedBy.isNotEmpty) {
        query = query.eq('posted_by', postedBy);
        debugPrint('listListings: posted_by 필터 추가 - $postedBy');
      }
      if (claimedBy != null && claimedBy.isNotEmpty) {
        query = query.eq('claimed_by', claimedBy);
        debugPrint('listListings: claimed_by 필터 추가 - $claimedBy');
      }
      
      debugPrint('listListings: 쿼리 실행 중...');
      debugPrint('listListings: 현재 사용자 ID - ${_sb.auth.currentUser?.id}');
      final data = await query.order('createdat', ascending: false);
      debugPrint('listListings: 쿼리 결과 - ${data.length}개 행');
      
      // 각 레코드의 상세 정보 로깅
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        debugPrint('listListings: 레코드 $i - id: ${item['id']}, status: ${item['status']}, posted_by: ${item['posted_by']}, title: ${item['title']}');
      }
      
      final result = data.map((e) => Map<String, dynamic>.from(e)).toList();
      debugPrint('listListings: 변환 완료 - ${result.length}개 항목');
      
      // 첫 번째 항목의 키들을 로그로 출력
      if (result.isNotEmpty) {
        debugPrint('listListings: 첫 번째 항목 키들 - ${result.first.keys.toList()}');
      }
      
      return result;
    } catch (e) {
      debugPrint('listListings error: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  Future<Map<String, dynamic>?> createListing({
    required String jobId,
    required String title,
    String? description,
    String? region,
    String? category,
    double? budgetAmount,
    DateTime? expiresAt,
  }) async {
    debugPrint('createListing 시작: jobId=$jobId, title=$title');
    
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('createListing 에러: 사용자 ID가 null');
      throw StateError('로그인이 필요합니다');
    }
    
    debugPrint('createListing: userId=$userId');
    
    final payload = {
      'jobid': jobId,
      'title': title,
      'description': description,
      'region': region,
      'category': category,
      'budget_amount': budgetAmount,
      'posted_by': userId,
      'status': 'open',
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    };
    
    debugPrint('createListing payload: $payload');
    
    try {
      final rows = await _sb.from('marketplace_listings').insert(payload).select().limit(1);
      debugPrint('createListing DB 결과: $rows');
      
      if (rows.isEmpty) {
        debugPrint('createListing: 결과가 비어있음');
        return null;
      }
      
      final result = Map<String, dynamic>.from(rows.first);
      debugPrint('createListing 성공: $result');
      return result;
    } catch (e) {
      debugPrint('createListing DB 에러: $e');
      rethrow;
    }
  }

  Future<bool> claimListing(String listingId) async {
    final businessId = _sb.auth.currentUser?.id;
    if (businessId == null) {
      throw StateError('로그인이 필요합니다');
    }
    try {
      final result = await _sb.rpc('claim_listing', params: {
        'p_listing_id': listingId,
        'p_business_id': businessId,
      });
      if (result is bool) {
        return result;
      }
      return false;
    } on PostgrestException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> withdrawClaimForJob(String jobId) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다');
    try {
      // find listing by jobid and assigned
      final rows = await _sb
          .from('marketplace_listings')
          .select('id, claimed_by, status')
          .eq('jobid', jobId)
          .eq('status', 'assigned')
          .limit(1);
      if (rows.isEmpty) return false;
      final listingId = rows.first['id'].toString();
      // reopen listing
      await _sb
          .from('marketplace_listings')
          .update({'status': 'open', 'claimed_by': null, 'claimed_at': null, 'updatedat': DateTime.now().toIso8601String()})
          .eq('id', listingId);
      // reset job assignment
      await _sb
          .from('jobs')
          .update({'assigned_business_id': null, 'status': 'created'})
          .eq('id', jobId);
      return true;
    } catch (e) {
      debugPrint('withdrawClaimForJob error: $e');
      return false;
    }
  }
}


