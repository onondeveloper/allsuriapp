import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/role.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/estimate.dart';
import '../models/order.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedStatus = '전체';
  String _selectedUserType = '전체';

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebDashboard(context);
    } else {
      return _buildMobileDashboard(context);
    }
  }

  Widget _buildWebDashboard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allsuri 관리자 웹 대시보드'),
        centerTitle: true,
        backgroundColor: const Color(0xFF00C6AE),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        children: [
          // 사이드바 네비게이션
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFFF8F9FB),
            selectedIconTheme: const IconThemeData(color: Color(0xFF00C6AE)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF00C6AE)),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('대시보드'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('사용자 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment),
                label: Text('견적 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('통계'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message),
                label: Text('메시징'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('설정'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 메인 컨텐츠
          Expanded(
            child: _buildWebContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent(context);
      case 1:
        return _buildUserManagementContent(context);
      case 2:
        return _buildEstimateManagementContent(context);
      case 3:
        return _buildStatisticsContent(context);
      case 4:
        return _buildMessagingContent(context);
      case 5:
        return _buildSettingsContent(context);
      default:
        return _buildDashboardContent(context);
    }
  }

  Widget _buildDashboardContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '관리자 대시보드',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 32),
          // 통계 카드
          Row(
            children: [
              Expanded(child: _buildStatCard(context, '전체 사업자', '24', Icons.business, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '대기 중인 사업자', '3', Icons.pending, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '진행 중인 견적', '156', Icons.assignment, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '완료된 견적', '89', Icons.check_circle, Colors.purple)),
            ],
          ),
          const SizedBox(height: 32),
          // 최근 활동 테이블
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최근 활동',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentActivityTable(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사용자 관리',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF222B45),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // 새 사용자 추가
                },
                icon: const Icon(Icons.add),
                label: const Text('새 사용자 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C6AE),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 검색 및 필터
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '사용자 검색...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedUserType,
                    items: ['전체', '사업자', '고객', '관리자']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUserType = value!;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    items: ['전체', '승인됨', '대기 중', '거절됨']
                        .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 사용자 테이블
          Card(
            child: _buildUserTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateManagementContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '견적 관리',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 24),
          // 견적 통계
          Row(
            children: [
              Expanded(child: _buildStatCard(context, '전체 견적', '245', Icons.assignment, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '진행 중', '156', Icons.pending, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '완료됨', '89', Icons.check_circle, Colors.green)),
            ],
          ),
          const SizedBox(height: 24),
          // 견적 테이블
          Card(
            child: _buildEstimateTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '통계 및 과금',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 32),
          // 통계 카드들
          Row(
            children: [
              Expanded(child: _buildStatCard(context, '월 수익', '₩2,450,000', Icons.attach_money, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '활성 사업자', '18', Icons.business, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, '평균 견적가', '₩850,000', Icons.analytics, Colors.orange)),
            ],
          ),
          const SizedBox(height: 32),
          // 차트 영역
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '월별 수익 추이',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('차트 영역 (Chart.js 또는 Flutter Charts 사용)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '지역별 견적 분포',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('파이 차트 영역'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 과금 테이블
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '사업자별 과금 현황',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBillingTable(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagingContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메시징 시스템',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '새 메시지 작성',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: '받는 사람',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: '제목',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '메시지 내용',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C6AE),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('전송'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {},
                              child: const Text('임시저장'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '메시지 내역',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMessageHistoryTable(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '시스템 설정',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222B45),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '일반 설정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('이메일 알림'),
                    subtitle: const Text('새 사용자 등록 시 이메일 알림을 받습니다'),
                    value: true,
                    onChanged: (value) {},
                  ),
                  SwitchListTile(
                    title: const Text('SMS 알림'),
                    subtitle: const Text('중요한 업데이트 시 SMS 알림을 받습니다'),
                    value: false,
                    onChanged: (value) {},
                  ),
                  SwitchListTile(
                    title: const Text('자동 승인'),
                    subtitle: const Text('사업자 등록 시 자동으로 승인합니다'),
                    value: false,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('시간')),
          DataColumn(label: Text('사용자')),
          DataColumn(label: Text('활동')),
          DataColumn(label: Text('상세')),
          DataColumn(label: Text('상태')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('2024-01-15 14:30')),
            const DataCell(Text('김사업자')),
            const DataCell(Text('견적 생성')),
            const DataCell(Text('서울시 강남구 인테리어 견적')),
            const DataCell(Text('완료')),
          ]),
          DataRow(cells: [
            const DataCell(Text('2024-01-15 13:45')),
            const DataCell(Text('이고객')),
            const DataCell(Text('견적 요청')),
            const DataCell(Text('부산시 해운대구 리모델링')),
            const DataCell(Text('진행 중')),
          ]),
          DataRow(cells: [
            const DataCell(Text('2024-01-15 12:20')),
            const DataCell(Text('박사업자')),
            const DataCell(Text('계정 승인')),
            const DataCell(Text('신규 사업자 등록')),
            const DataCell(Text('승인됨')),
          ]),
        ],
      ),
    );
  }

  Widget _buildUserTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('이름')),
          DataColumn(label: Text('이메일')),
          DataColumn(label: Text('역할')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('가입일')),
          DataColumn(label: Text('액션')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('김사업자')),
            const DataCell(Text('business@example.com')),
            const DataCell(Text('사업자')),
            const DataCell(Text('승인됨')),
            const DataCell(Text('2024-01-10')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
          DataRow(cells: [
            const DataCell(Text('이고객')),
            const DataCell(Text('customer@example.com')),
            const DataCell(Text('고객')),
            const DataCell(Text('활성')),
            const DataCell(Text('2024-01-08')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
          DataRow(cells: [
            const DataCell(Text('박신규')),
            const DataCell(Text('new@example.com')),
            const DataCell(Text('사업자')),
            const DataCell(Text('대기 중')),
            const DataCell(Text('2024-01-15')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildEstimateTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('견적 ID')),
          DataColumn(label: Text('고객')),
          DataColumn(label: Text('사업자')),
          DataColumn(label: Text('서비스')),
          DataColumn(label: Text('금액')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('생성일')),
          DataColumn(label: Text('액션')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('EST-001')),
            const DataCell(Text('김고객')),
            const DataCell(Text('인테리어업체')),
            const DataCell(Text('인테리어')),
            const DataCell(Text('₩2,500,000')),
            const DataCell(Text('진행 중')),
            const DataCell(Text('2024-01-15')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
          DataRow(cells: [
            const DataCell(Text('EST-002')),
            const DataCell(Text('이고객')),
            const DataCell(Text('리모델링업체')),
            const DataCell(Text('리모델링')),
            const DataCell(Text('₩5,000,000')),
            const DataCell(Text('완료')),
            const DataCell(Text('2024-01-14')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildBillingTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('사업자')),
          DataColumn(label: Text('지역')),
          DataColumn(label: Text('입찰 횟수')),
          DataColumn(label: Text('낙찰 횟수')),
          DataColumn(label: Text('수익률')),
          DataColumn(label: Text('월 수익')),
          DataColumn(label: Text('액션')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('인테리어업체')),
            const DataCell(Text('서울시 강남구')),
            const DataCell(Text('15')),
            const DataCell(Text('8')),
            const DataCell(Text('53%')),
            const DataCell(Text('₩400,000')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.message, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
          DataRow(cells: [
            const DataCell(Text('리모델링업체')),
            const DataCell(Text('부산시 해운대구')),
            const DataCell(Text('12')),
            const DataCell(Text('6')),
            const DataCell(Text('50%')),
            const DataCell(Text('₩300,000')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.analytics, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.message, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildMessageHistoryTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('날짜')),
          DataColumn(label: Text('받는 사람')),
          DataColumn(label: Text('제목')),
          DataColumn(label: Text('상태')),
          DataColumn(label: Text('액션')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('2024-01-15')),
            const DataCell(Text('전체 사업자')),
            const DataCell(Text('새로운 기능 업데이트 안내')),
            const DataCell(Text('전송됨')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
          DataRow(cells: [
            const DataCell(Text('2024-01-14')),
            const DataCell(Text('인테리어업체')),
            const DataCell(Text('견적 승인 알림')),
            const DataCell(Text('전송됨')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 16),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () {},
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildMobileDashboard(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildStatisticsCards(context),
            const SizedBox(height: 32),
            _buildSection(
              context,
              '사용자 관리',
              [
                _buildActionCard(
                  context,
                  Icons.people,
                  '사업자 관리',
                  '사업자 계정을 승인/거절하고 관리합니다',
                  () {
                    context.push('/admin/user-management');
                  },
                ),
                _buildActionCard(
                  context,
                  Icons.search,
                  '사업자 검색',
                  '사업자 정보와 입찰/낙찰 내역을 검색합니다',
                  () {},
                ),
                _buildActionCard(
                  context,
                  Icons.analytics,
                  '고객 견적 현황',
                  '고객들이 낸 모든 견적 정보를 확인합니다',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '견적 관리',
              [
                _buildActionCard(
                  context,
                  Icons.dashboard,
                  '견적 현황 대시보드',
                  '진행 중인 모든 견적을 상태별로 확인합니다',
                  () {
                    context.push('/admin/estimate-dashboard');
                  },
                ),
                _buildActionCard(
                  context,
                  Icons.assessment,
                  '과금 관리',
                  '사업자별 입찰/낙찰 횟수와 지역 정보를 관리합니다',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '시스템 관리',
              [
                _buildActionCard(
                  context,
                  Icons.settings,
                  '시스템 설정',
                  '앱 설정과 관리자 권한을 관리합니다',
                  () {},
                ),
                _buildActionCard(
                  context,
                  Icons.web,
                  '웹 대시보드',
                  '웹 페이지에서 관리자 기능을 확인합니다',
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '관리자 대시보드',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF222B45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '사용자 관리, 견적 현황, 시스템 설정을 한 곳에서 관리하세요',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          '전체 사업자',
          '24',
          Icons.business,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          '대기 중인 사업자',
          '3',
          Icons.pending,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          '진행 중인 견적',
          '156',
          Icons.assignment,
          Colors.green,
        ),
        _buildStatCard(
          context,
          '완료된 견적',
          '89',
          Icons.check_circle,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF222B45),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: children,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFF8F9FB),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C6AE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: const Color(0xFF00C6AE),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222B45),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '관리자 가이드',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 사업자 관리: 새로운 사업자 계정을 승인하고 관리합니다.\n'
            '• 견적 현황: 진행 중인 모든 견적을 상태별로 확인합니다.\n'
            '• 과금 관리: 사업자별 입찰/낙찰 통계를 관리합니다.',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
} 