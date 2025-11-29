import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/api_service.dart';

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

  Future<int> countListings({
    String status = 'open',
    String? region,
    String? category,
    String? postedBy,
    String? excludePostedBy,
  }) async {
    try {
      var query = _sb.from('marketplace_listings').select('*', FetchOptions(count: CountOption.exact, head: true));
      
      if (status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      } else if (status == 'all') {
        query = query.inFilter('status', ['open', 'withdrawn', 'created']);
      }
      
      if (region != null && region.isNotEmpty) {
        query = query.eq('region', region);
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (postedBy != null && postedBy.isNotEmpty) {
        query = query.eq('posted_by', postedBy);
      }
      if (excludePostedBy != null && excludePostedBy.isNotEmpty) {
        query = query.neq('posted_by', excludePostedBy);
      }
      
      final response = await query.count();
      return response.count;
    } catch (e) {
      debugPrint('countListings error: $e');
      return 0;
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

  Future<bool> claimListing(String listingId, {required String businessId}) async {
    try {
      debugPrint('🔍 [MarketplaceService.claimListing] 시작: $listingId');
      debugPrint('   사용자 ID: $businessId');
      
      // Backend API를 통해 claim (Supabase 세션 없이도 작동)
      final api = ApiService();
      
      // 입찰 시스템 사용: 즉시 가져가기가 아닌 입찰 후 승인 프로세스
      final response = await api.post('/market/listings/$listingId/bid', {
        'businessId': businessId,
        'message': '이 오더를 맡고 싶습니다.',
      });
      
      debugPrint('   응답: ${response}');
      
      if (response['success'] == true) {
        debugPrint('✅ [MarketplaceService.claimListing] 성공');
        return true;
      }
      
      debugPrint('❌ [MarketplaceService.claimListing] 실패: ${response['message']}');
      return false;
    } catch (e) {
      debugPrint('❌ [MarketplaceService.claimListing] 에러: $e');
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


