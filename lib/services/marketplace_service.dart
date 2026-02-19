import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/api_service.dart';

class MarketplaceService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;
  final ApiService _api = ApiService();

  Future<List<Map<String, dynamic>>> listListings({
    String status = 'open',
    String? region,
    String? category,
    bool throwOnError = false,
    String? postedBy,
    String? claimedBy,
    int? limit,
    int? offset,
  }) async {
    debugPrint('listListings 시작: status=$status, limit=$limit, offset=$offset');
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
      
      // ⚡ 성능 개선: 페이지네이션 및 정렬
      var transformedQuery = query.order('createdat', ascending: false);
      
      if (limit != null && offset != null) {
        debugPrint('listListings: range 추가 - offset: $offset, limit: $limit');
        transformedQuery = transformedQuery.range(offset, offset + limit - 1);
      } else if (limit != null) {
        debugPrint('listListings: limit 추가 - $limit');
        transformedQuery = transformedQuery.limit(limit);
      }
      
      final data = await transformedQuery;
      debugPrint('listListings: 쿼리 결과 - ${data.length}개 행');
      
      // 각 레코드의 상세 정보 로깅
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        debugPrint('listListings: 레코드 $i - id: ${item['id']}, status: ${item['status']}, posted_by: ${item['posted_by']}, title: ${item['title']}');
      }
      
      final result = data.map((e) => Map<String, dynamic>.from(e)).toList();
      debugPrint('listListings: 변환 완료 - ${result.length}개 항목');
      
      // 오더 생성자 정보 가져오기 (사업자 상호명, 평점)
      final postedByIds = result
          .map((e) => e['posted_by']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();
      
      if (postedByIds.isNotEmpty) {
        debugPrint('listListings: ${postedByIds.length}명의 사업자 정보 조회 중...');
        
        // 병렬로 사업자 정보와 평점 조회
        final usersFutures = postedByIds.map((userId) async {
          try {
            if (userId == null) return null;
            
            // 사업자 정보 조회
            final user = await _sb
                .from('users')
                .select('id, businessname, name')
                .eq('id', userId)
                .maybeSingle();
            
            if (user == null) return null;
            
            // 평점 조회
            final reviews = await _sb
                .from('reviews')
                .select('rating')
                .eq('businessid', userId);
            
            double avgRating = 0.0;
            int reviewCount = reviews.length;
            
            if (reviewCount > 0) {
              final totalRating = reviews.fold<double>(
                0.0, 
                (sum, review) {
                  final rating = review['rating'];
                  if (rating is num) {
                    return sum + rating.toDouble();
                  }
                  return sum;
                }
              );
              avgRating = totalRating / reviewCount;
            }
            
            return {
              'id': userId,
              'businessName': user['businessname'] ?? user['name'] ?? '알 수 없음',
              'avgRating': avgRating,
              'reviewCount': reviewCount,
            };
          } catch (e) {
            debugPrint('사업자 정보 조회 실패 ($userId): $e');
            return null;
          }
        }).toList();
        
        final usersData = await Future.wait(usersFutures);
        final usersMap = <String, Map<String, dynamic>>{};
        
        for (final userData in usersData) {
          if (userData != null) {
            usersMap[userData['id']] = userData;
          }
        }
        
        // 각 오더에 사업자 정보 추가
        for (final listing in result) {
          final postedById = listing['posted_by']?.toString();
          if (postedById != null && usersMap.containsKey(postedById)) {
            listing['owner_business_name'] = usersMap[postedById]!['businessName'];
            listing['owner_avg_rating'] = usersMap[postedById]!['avgRating'];
            listing['owner_review_count'] = usersMap[postedById]!['reviewCount'];
          }
        }
        
        debugPrint('✅ listListings: 사업자 정보 추가 완료');
      }
      
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
      var query = _sb.from('marketplace_listings').select('*');
      
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
      
      final response = await query.count(CountOption.exact);
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
    String? postedBy, // 사용자 ID를 직접 전달받도록 추가
  }) async {
    debugPrint('createListing 시작: jobId=$jobId, title=$title');
    
    // postedBy가 전달되면 사용, 없으면 Supabase auth 확인
    final userId = postedBy ?? _sb.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('createListing 에러: 사용자 ID가 null');
      throw StateError('로그인이 필요합니다');
    }
    
    debugPrint('createListing: userId=$userId');
    
    // Supabase에 직접 INSERT (service_role을 사용하면 RLS 우회)
    final payload = {
      'jobid': jobId,
      'title': title,
      'description': description,
      'region': region,
      'category': category,
      'budget_amount': budgetAmount,
      'posted_by': userId,
      'status': 'created', // 'created' 상태로 시작
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    };
    
    debugPrint('createListing payload: $payload');
    
    try {
      // 동일한 jobId로 이미 등록된 오더가 있는지 확인 (중복 방지)
      final existing = await _sb
          .from('marketplace_listings')
          .select('id, status')
          .eq('jobid', jobId)
          .limit(1);
      
      if (existing.isNotEmpty) {
        debugPrint('⚠️ createListing: 이미 등록된 오더가 있습니다 (jobId: $jobId)');
        debugPrint('   기존 오더 ID: ${existing.first['id']}, 상태: ${existing.first['status']}');
        // 기존 오더 반환 (새로 생성하지 않음)
        return Map<String, dynamic>.from(existing.first);
      }
      
      // Supabase 직접 INSERT (anon 키 사용, RLS 정책 통과 필요)
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
      // RLS 에러인 경우 상세 정보 출력
      if (e.toString().contains('row-level security')) {
        debugPrint('⚠️ RLS 정책 위반: Supabase Auth 세션이 필요합니다');
        debugPrint('   현재 auth.uid(): ${_sb.auth.currentUser?.id}');
        debugPrint('   전달된 postedBy: $userId');
      }
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

  /// 오더 삭제 (공사 및 마켓플레이스 리스팅 삭제)
  /// - 낙찰 전 상태여야 함 (status: created, open)
  Future<bool> deleteListing(String listingId, String jobId) async {
    try {
      debugPrint('🔍 [MarketplaceService.deleteListing] 시작: listingId=$listingId, jobId=$jobId');
      
      // 1. 입찰 내역 삭제 (있을 경우)
      await _sb.from('order_bids').delete().eq('listing_id', listingId);
      
      // 2. 마켓플레이스 리스팅 삭제
      // jobid cascade가 걸려있으므로 job만 삭제해도 되지만, 명시적으로 listing 먼저 삭제 시도
      await _sb.from('marketplace_listings').delete().eq('id', listingId);
      
      // 3. 원본 공사 삭제
      await _sb.from('jobs').delete().eq('id', jobId);
      
      debugPrint('✅ [MarketplaceService.deleteListing] 삭제 성공');
      return true;
    } catch (e) {
      debugPrint('❌ [MarketplaceService.deleteListing] 삭제 실패: $e');
      return false;
    }
  }
}


