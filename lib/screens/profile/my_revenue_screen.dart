import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_indicator.dart';

/// 내 매출 화면
/// 완료한 공사 수, 견적 합산 금액, 수수료 합산 금액, 평균 수수료율, 평점을 표시
class MyRevenueScreen extends StatefulWidget {
  const MyRevenueScreen({Key? key}) : super(key: key);

  @override
  State<MyRevenueScreen> createState() => _MyRevenueScreenState();
}

class _MyRevenueScreenState extends State<MyRevenueScreen> {
  bool _isLoading = true;
  int _completedJobsCount = 0;
  double _totalEstimateAmount = 0;
  double _totalCommissionAmount = 0;
  double _averageCommissionRate = 0;
  double _averageRating = 0;
  int _totalReviews = 0;
  Map<int, int> _ratingDistribution = {}; // 별점별 개수
  Map<String, double> _monthlyCommission = {}; // 월별 수수료 (YYYY-MM: 금액)

  @override
  void initState() {
    super.initState();
    _loadRevenueData();
  }

  Future<void> _loadRevenueData() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id;

      if (currentUserId == null) return;

      print('🔍 [MyRevenue] 매출 데이터 로드 시작: userId=$currentUserId');

      // 최근 6개월 날짜 계산
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
      final sixMonthsAgoStr = sixMonthsAgo.toIso8601String();
      
      print('   조회 기간: ${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-${sixMonthsAgo.day} ~ ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day}');

      // 1. 완료된 공사 조회 (최근 6개월, 내가 낙찰받아 완료한 공사)
      // awarded_amount가 없으면 jobs.budget_amount 사용
      final jobs = await Supabase.instance.client
          .from('jobs')
          .select('id, awarded_amount, budget_amount, commission_rate, status, updated_at')
          .eq('assigned_business_id', currentUserId)
          .inFilter('status', ['completed', 'awaiting_confirmation'])
          .gte('updated_at', sixMonthsAgoStr)
          .order('updated_at', ascending: false);

      print('   조회된 공사: ${jobs.length}개 (최근 6개월)');

      _completedJobsCount = jobs.length;

      // 2. 견적 합산 금액 및 수수료 계산 + 월별 수수료 집계
      double totalEstimate = 0;
      double totalCommission = 0;
      int commissionCount = 0;
      int jobsWithAmount = 0;
      Map<String, double> monthlyCommission = {};

      for (var job in jobs) {
        print('   공사: ${job['id']}');
        print('      awarded_amount: ${job['awarded_amount']}');
        print('      budget_amount: ${job['budget_amount']}');
        print('      commission_rate: ${job['commission_rate']}');
        
        // awarded_amount가 있으면 사용, 없으면 budget_amount 사용
        final awardedAmount = job['awarded_amount'] ?? job['budget_amount'];
        final commissionRate = job['commission_rate'];
        final updatedAt = job['updated_at'] as String?;
        
        if (awardedAmount == null) {
          print('      ⚠️ awarded_amount와 budget_amount 모두 null');
          continue;
        }

        final amount = awardedAmount is num 
            ? awardedAmount.toDouble() 
            : double.tryParse(awardedAmount.toString()) ?? 0;
        
        if (amount > 0) {
          totalEstimate += amount;
          jobsWithAmount++;
          print('      ✅ 금액: ${amount}원');
          
          if (commissionRate != null) {
            final rate = commissionRate is num 
                ? commissionRate.toDouble() 
                : double.tryParse(commissionRate.toString()) ?? 0;
            
            if (rate > 0) {
              final commission = amount * (rate / 100);
              totalCommission += commission;
              commissionCount++;
              print('      💰 수수료: ${amount}원 × ${rate}% = ${commission}원');
              
              // 월별 수수료 집계
              if (updatedAt != null) {
                try {
                  final date = DateTime.parse(updatedAt);
                  final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                  monthlyCommission[monthKey] = (monthlyCommission[monthKey] ?? 0) + commission;
                  print('      📅 월별: $monthKey → ${monthlyCommission[monthKey]}원');
                } catch (e) {
                  print('      ⚠️ 날짜 파싱 실패: $updatedAt');
                }
              }
            }
          }
        }
      }

      _totalEstimateAmount = totalEstimate;
      _totalCommissionAmount = totalCommission;
      _averageCommissionRate = totalEstimate > 0 ? (totalCommission / totalEstimate * 100) : 0;
      _monthlyCommission = monthlyCommission;

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 [MyRevenue] 계산 결과:');
      print('   완료한 공사: $_completedJobsCount건');
      print('   금액이 있는 공사: $jobsWithAmount건');
      print('   총 견적 금액: ${_totalEstimateAmount.toStringAsFixed(0)}원');
      print('   총 수수료: ${_totalCommissionAmount.toStringAsFixed(0)}원');
      print('   평균 수수료율: ${_averageCommissionRate.toStringAsFixed(1)}%');
      print('   월별 수수료 데이터: ${_monthlyCommission.length}개월');
      _monthlyCommission.forEach((month, amount) {
        print('      $month: ${amount.toStringAsFixed(0)}원');
      });
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // 3. 평점 조회 (최근 6개월, 내가 받은 리뷰)
      final reviews = await Supabase.instance.client
          .from('order_reviews')
          .select('rating, created_at')
          .eq('reviewee_id', currentUserId)
          .gte('created_at', sixMonthsAgoStr);

      print('   조회된 리뷰: ${reviews.length}개 (최근 6개월)');

      _totalReviews = reviews.length;

      if (reviews.isNotEmpty) {
        double totalRating = 0;
        Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

        for (var review in reviews) {
          final rating = review['rating'];
          if (rating != null) {
            final ratingValue = rating is num ? rating.toDouble() : double.tryParse(rating.toString()) ?? 0;
            totalRating += ratingValue;

            // 별점 분포 계산
            final ratingInt = ratingValue.round();
            if (ratingInt >= 1 && ratingInt <= 5) {
              distribution[ratingInt] = (distribution[ratingInt] ?? 0) + 1;
            }
          }
        }

        _averageRating = totalRating / reviews.length;
        _ratingDistribution = distribution;

        print('   평균 평점: ${_averageRating.toStringAsFixed(1)}점');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ [MyRevenue] 매출 데이터 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '내 매출',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
            onPressed: _loadRevenueData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: '매출 데이터를 불러오는 중...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 매출 요약 카드
                  _buildRevenueSummary(),
                  const SizedBox(height: 20),
                  
                  // 매출 그래프
                  _buildRevenueChart(),
                  const SizedBox(height: 20),
                  
                  // 평점 섹션
                  _buildRatingSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueSummary() {
    return Column(
      children: [
        // 총 수수료 수익 (메인 카드)
        _buildMainRevenueCard(),
        const SizedBox(height: 12),
        // 완료한 공사, 평균 수수료율 (2열 그리드)
        Row(
          children: [
            Expanded(child: _buildStatCard(
              '완료한 공사',
              '$_completedJobsCount건',
              Icons.check_circle_outline,
              const Color(0xFF10B981),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              '평균 수수료율',
              '${_averageCommissionRate.toStringAsFixed(1)}%',
              Icons.trending_up,
              const Color(0xFF8B5CF6),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMainRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '총 수수료 수익',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '최근 6개월',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatNumberWithComma(_totalCommissionAmount),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '원',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    // 최근 6개월 데이터 준비
    final now = DateTime.now();
    final List<String> last6Months = [];
    final List<double> commissionData = [];
    double maxCommission = 0;

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      last6Months.add(monthKey);
      
      final commission = _monthlyCommission[monthKey] ?? 0;
      commissionData.add(commission);
      
      if (commission > maxCommission) {
        maxCommission = commission;
      }
    }

    // 데이터가 없으면 기본값 설정
    if (maxCommission == 0) {
      maxCommission = 100000; // 10만원을 기본 최대값으로
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '월별 수수료 현황',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '최근 6개월',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '실제 수익 추이',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                maxY: maxCommission * 1.2,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxCommission > 0 ? maxCommission / 4 : 25000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < last6Months.length) {
                          final parts = last6Months[index].split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${parts[1]}월',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatNumberShort(value),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      commissionData.length,
                      (index) => FlSpot(index.toDouble(), commissionData[index]),
                    ),
                    isCurved: true,
                    color: const Color(0xFFF59E0B),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFFF59E0B),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF59E0B).withOpacity(0.3),
                          const Color(0xFFF59E0B).withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF1E3A8A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final parts = last6Months[index].split('-');
                        return LineTooltipItem(
                          '${parts[0]}년 ${parts[1]}월\n${_formatNumberWithComma(spot.y)}원',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내 평점',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '최근 6개월 · 총 $_totalReviews개의 리뷰',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          
          // 별점 분포
          if (_totalReviews > 0) ...[
            for (int star = 5; star >= 1; star--) _buildRatingBar(star, _ratingDistribution[star] ?? 0),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      '아직 받은 리뷰가 없습니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, int count) {
    final percentage = (_totalReviews > 0 ? count / _totalReviews : 0.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Row(
              children: [
                Text(
                  '$star',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 100000000) {
      return '${(number / 100000000).toStringAsFixed(1)}억';
    } else if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(0)}만';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  String _formatNumberShort(double number) {
    if (number >= 100000000) {
      return '${(number / 100000000).toStringAsFixed(0)}억';
    } else if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(0)}만';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}천';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  String _formatNumberWithComma(double number) {
    // 숫자를 천단위 콤마로 표시 (예: 690000 → 690,000)
    final intValue = number.toInt();
    final parts = <String>[];
    var remaining = intValue;
    
    while (remaining > 0) {
      final part = remaining % 1000;
      remaining = remaining ~/ 1000;
      
      if (remaining > 0) {
        parts.add(part.toString().padLeft(3, '0'));
      } else {
        parts.add(part.toString());
      }
    }
    
    if (parts.isEmpty) return '0';
    return parts.reversed.join(',');
  }
}

