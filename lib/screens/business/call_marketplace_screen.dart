import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:allsuriapp/services/marketplace_service.dart';
import 'package:allsuriapp/screens/business/estimate_management_screen.dart';
import 'package:allsuriapp/widgets/interactive_card.dart';
import 'package:allsuriapp/widgets/shimmer_widgets.dart';
import 'package:allsuriapp/services/chat_service.dart';
import 'package:provider/provider.dart';
import 'package:allsuriapp/models/estimate.dart';
import 'package:allsuriapp/services/estimate_service.dart';

class CallMarketplaceScreen extends StatefulWidget {
  final bool showSuccessMessage;
  final String? createdByUserId;
  
  const CallMarketplaceScreen({
    Key? key,
    this.showSuccessMessage = false,
    this.createdByUserId,
  }) : super(key: key);

  @override
  State<CallMarketplaceScreen> createState() => _CallMarketplaceScreenState();
}

class _CallMarketplaceScreenState extends State<CallMarketplaceScreen> {
  final MarketplaceService _market = MarketplaceService();
  late Future<List<Map<String, dynamic>>> _future;
  String _status = 'all';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    print('CallMarketplaceScreen initState 시작');
    _future = _market.listListings(status: _status, throwOnError: true, postedBy: widget.createdByUserId);
    print('CallMarketplaceScreen: _future 설정됨');
    
    _channel = Supabase.instance.client
        .channel('public:marketplace_listings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'marketplace_listings',
          callback: (payload) {
            print('CallMarketplaceScreen Realtime 이벤트: $payload');
            if (!mounted) return;
            _reload();
          },
        )
        .subscribe();
    print('CallMarketplaceScreen: Realtime 구독 완료');
    
    // Call 공사 등록 성공 후 이동한 경우 성공 메시지 표시
    if (widget.showSuccessMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call에 성공적으로 등록되었습니다!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    // 화면 진입 직후 한번 더 새로고침하여 데이터 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reload();
      }
    });
  }

  Future<void> _reload() async {
    print('CallMarketplaceScreen _reload 시작: status=$_status');
    setState(() {
      _future = _market.listListings(status: _status, postedBy: widget.createdByUserId);
    });
    print('CallMarketplaceScreen _reload 완료');
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 제거: 항상 오픈(또는 withdrawn) 항목만 표시
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  print('CallMarketplaceScreen FutureBuilder: connectionState=${snapshot.connectionState}, hasError=${snapshot.hasError}, data=${snapshot.data?.length ?? 0}');
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print('CallMarketplaceScreen: 로딩 중...');
                    return const ShimmerList(itemCount: 6, itemHeight: 110);
                  }
                  if (snapshot.hasError) {
                    print('CallMarketplaceScreen: 에러 발생 - ${snapshot.error}');
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text('불러오기 실패: ')),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('${snapshot.error}'),
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? [];
                  final visibleItems = items.where((row) {
                    final s = (row['status'] ?? '').toString();
                    return s == 'open' || s == 'withdrawn';
                  }).toList();
                  print('CallMarketplaceScreen: 데이터 로드 완료 - ${visibleItems.length}개 항목(오픈/철회만)');
                  if (visibleItems.isEmpty) {
                    print('CallMarketplaceScreen: 빈 목록 표시');
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 160),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '표시할 Call이 없습니다',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '아래로 당겨 새로고침하거나\n새로운 Call을 등록해보세요',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 디버깅 정보 추가
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '디버깅 정보',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('현재 상태: open', style: Theme.of(context).textTheme.bodySmall),
                                    Text(
                                      '데이터 개수: ${visibleItems.length}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final e = visibleItems[index];
                      final String id = (e['id'] ?? '').toString();
                      final String title = (e['title'] ?? e['description'] ?? '-') as String;
                      final String description = (e['description'] ?? '-') as String;
                      final String region = (e['region'] ?? '-') as String;
                      final String category = (e['category'] ?? '-') as String;
                      final String status = (e['status'] ?? '-') as String;
                      final createdAt = (e['createdat'] ?? e['createdAt']);
                      final budget = e['budget_amount'] ?? e['budgetAmount'];
                      final String? postedBy = (e['posted_by'] ?? e['postedBy'])?.toString();
                      final String jobId = (e['jobid'] ?? e['jobId'] ?? '').toString();
                      final String createdText = createdAt != null
                          ? (DateTime.tryParse(createdAt.toString())?.toLocal().toString().split('.').first ?? '-')
                          : '-';

                      // 상태 라벨은 이 화면에서 불필요 (항상 오픈/철회만 표시)

                      return InteractiveCard(
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text('지역: $region', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        const SizedBox(height: 6),
                                        Text('내용: $description', maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 6),
                                        if (budget != null)
                                          Text(
                                            '공사 금액: ${budget is num ? budget.toInt().toString() : budget.toString()}원',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        if (e['jobs'] != null && e['jobs'] is Map && (e['jobs']['commission_rate'] != null))
                                          Text('수수료율: ${(e['jobs']['commission_rate']).toString()}%'),
                                        const SizedBox(height: 8),
                                        Text(
                                          createdText,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 64,
                                    width: 90,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(0, 64),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: Colors.lightBlueAccent,
                                        foregroundColor: Colors.blue.shade900,
                                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: (status == 'open' || status == 'withdrawn')
                                          ? () async {
                                              final ok = await _market.claimListing(id);
                                              if (!mounted) return;
                                              if (ok) {
                                                final me = Supabase.instance.client.auth.currentUser?.id;
                                                if (postedBy != null && postedBy.isNotEmpty && me != null && me.isNotEmpty) {
                                                  try {
                                                    await ChatService().createChatRoom('call_$id', postedBy, me);
                                                  } catch (_) {}
                                                }
                                                if (me != null && me.isNotEmpty && jobId.isNotEmpty) {
                                                  try {
                                                    final estimateSvc = context.read<EstimateService>();
                                                    await estimateSvc.createEstimate(
                                                      Estimate(
                                                        id: '',
                                                        orderId: jobId,
                                                        customerId: '',
                                                        customerName: '고객',
                                                        businessId: me,
                                                        businessName: '사업자',
                                                        businessPhone: '',
                                                        equipmentType: '기타',
                                                        amount: (budget is num) ? budget.toDouble() : 0.0,
                                                        description: (e['description']?.toString() ?? title),
                                                        estimatedDays: 0,
                                                        createdAt: DateTime.now(),
                                                        visitDate: DateTime.now(),
                                                        status: Estimate.STATUS_COMPLETED,
                                                      ),
                                                    );
                                                  } catch (_) {}
                                                }
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => const EstimateManagementScreen(initialStatus: Estimate.STATUS_COMPLETED),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('이미 다른 사업자가 가져갔습니다')),
                                                );
                                              }
                                            }
                                          : null,
                                      child: const Text('잡기'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


