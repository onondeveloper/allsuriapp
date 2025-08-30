import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/business_review.dart';
import '../models/business_stats.dart';

class ReviewService {
  final SupabaseClient _sb = Supabase.instance.client;

  /// 사업자의 리뷰 목록 가져오기
  Future<List<BusinessReview>> getBusinessReviews(String businessId, {int? limit, int? offset}) async {
    try {
      var query = _sb
          .from('business_reviews')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await query;
      return response.map((review) => BusinessReview.fromMap(review)).toList();
    } catch (e) {
      print('사업자 리뷰 목록 가져오기 실패: $e');
      return [];
    }
  }

  /// 특정 주문에 대한 리뷰 가져오기
  Future<BusinessReview?> getReviewByOrder(String orderId) async {
    try {
      final response = await _sb
          .from('business_reviews')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (response != null) {
        return BusinessReview.fromMap(response);
      }
      return null;
    } catch (e) {
      print('주문별 리뷰 가져오기 실패: $e');
      return null;
    }
  }

  /// 리뷰 작성
  Future<String> createReview(BusinessReview review) async {
    try {
      final response = await _sb
          .from('business_reviews')
          .insert(review.toMap())
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      print('리뷰 작성 실패: $e');
      rethrow;
    }
  }

  /// 리뷰 수정
  Future<void> updateReview(String reviewId, Map<String, dynamic> updates) async {
    try {
      await _sb
          .from('business_reviews')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reviewId);
    } catch (e) {
      print('리뷰 수정 실패: $e');
      rethrow;
    }
  }

  /// 리뷰 삭제
  Future<void> deleteReview(String reviewId) async {
    try {
      await _sb
          .from('business_reviews')
          .delete()
          .eq('id', reviewId);
    } catch (e) {
      print('리뷰 삭제 실패: $e');
      rethrow;
    }
  }

  /// 사업자 통계 가져오기
  Future<BusinessStats?> getBusinessStats(String businessId) async {
    try {
      final response = await _sb
          .from('business_stats')
          .select()
          .eq('business_id', businessId)
          .maybeSingle();

      if (response != null) {
        return BusinessStats.fromMap(response);
      }
      return null;
    } catch (e) {
      print('사업자 통계 가져오기 실패: $e');
      return null;
    }
  }

  /// 리뷰 작성 가능 여부 확인
  Future<bool> canWriteReview(String orderId, String customerId) async {
    try {
      // 1. 이미 리뷰를 작성했는지 확인
      final existingReview = await getReviewByOrder(orderId);
      if (existingReview != null) {
        return false; // 이미 리뷰가 있음
      }

      // 2. 주문이 완료되었는지 확인
      final orderResponse = await _sb
          .from('orders')
          .select('status, customerid')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        return false; // 주문을 찾을 수 없음
      }

      // 주문 상태가 'completed'이고 고객 ID가 일치하는지 확인
      return orderResponse['status'] == 'completed' && 
             orderResponse['customerid'] == customerId;
    } catch (e) {
      print('리뷰 작성 가능 여부 확인 실패: $e');
      return false;
    }
  }

  /// 사업자별 평균 별점 계산
  Future<double> calculateAverageRating(String businessId) async {
    try {
      final response = await _sb
          .from('business_reviews')
          .select('rating')
          .eq('business_id', businessId);

      if (response.isEmpty) return 0.0;

      final ratings = response.map((r) => r['rating'] as int).toList();
      final sum = ratings.reduce((a, b) => a + b);
      return sum / ratings.length;
    } catch (e) {
      print('평균 별점 계산 실패: $e');
      return 0.0;
    }
  }

  /// 리뷰 통계 요약
  Future<Map<String, dynamic>> getReviewSummary(String businessId) async {
    try {
      final response = await _sb
          .from('business_reviews')
          .select('rating')
          .eq('business_id', businessId);

      if (response.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {},
        };
      }

      final ratings = response.map((r) => r['rating'] as int).toList();
      final totalReviews = ratings.length;
      final averageRating = ratings.reduce((a, b) => a + b) / totalReviews;

      // 별점별 분포 계산
      final ratingDistribution = <int, int>{};
      for (int i = 1; i <= 5; i++) {
        ratingDistribution[i] = ratings.where((r) => r == i).length;
      }

      return {
        'totalReviews': totalReviews,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
      };
    } catch (e) {
      print('리뷰 통계 요약 실패: $e');
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'ratingDistribution': {},
      };
    }
  }
}
