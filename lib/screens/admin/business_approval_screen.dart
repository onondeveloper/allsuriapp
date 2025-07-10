import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/role.dart';

class BusinessApprovalScreen extends StatefulWidget {
  const BusinessApprovalScreen({Key? key}) : super(key: key);

  @override
  State<BusinessApprovalScreen> createState() => _BusinessApprovalScreenState();
}

class _BusinessApprovalScreenState extends State<BusinessApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TODO: Replace with actual data from backend
  final List<User> _pendingBusinesses = [
    User(
      id: '4',
      email: 'pending@example.com',
      name: '신청자1',
      role: UserRole.business,
      businessName: '올수리 서비스2',
      businessLicense: '123-45-67891',
      isActive: false,
    ),
  ];

  final List<User> _approvedBusinesses = [
    User(
      id: '2',
      email: 'business@example.com',
      name: '사업자1',
      role: UserRole.business,
      businessName: '올수리 서비스',
      businessLicense: '123-45-67890',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사업자 승인'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '승인 대기'),
            Tab(text: '승인 완료'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildApprovedList(),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingBusinesses.isEmpty) {
      return const Center(
        child: Text('승인 대기중인 사업자가 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: _pendingBusinesses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final business = _pendingBusinesses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(business.businessName ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대표자: ${business.name}'),
                Text('사업자등록번호: ${business.businessLicense}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _showApprovalDialog(business),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _showRejectDialog(business),
                ),
              ],
            ),
            onTap: () => _showBusinessDetailsDialog(business),
          ),
        );
      },
    );
  }

  Widget _buildApprovedList() {
    if (_approvedBusinesses.isEmpty) {
      return const Center(
        child: Text('승인된 사업자가 없습니다.'),
      );
    }

    return ListView.builder(
      itemCount: _approvedBusinesses.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final business = _approvedBusinesses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(business.businessName ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('대표자: ${business.name}'),
                Text('사업자등록번호: ${business.businessLicense}'),
              ],
            ),
            trailing: const Icon(Icons.verified, color: Colors.green),
            onTap: () => _showBusinessDetailsDialog(business),
          ),
        );
      },
    );
  }

  void _showBusinessDetailsDialog(User business) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(business.businessName ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('대표자: ${business.name}'),
            Text('이메일: ${business.email}'),
            Text('사업자등록번호: ${business.businessLicense}'),
            if (business.phoneNumber != null)
              Text('연락처: ${business.phoneNumber}'),
            if (business.address != null) Text('주소: ${business.address}'),
            Text('신청일: ${business.createdAt.toString().split('.')[0]}'),
            Text('상태: ${business.isActive ? "승인" : "대기중"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(User business) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업자 승인'),
        content: Text('${business.businessName}을(를) 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement approval functionality
              Navigator.pop(context);
            },
            child: const Text('승인'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(User business) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사업자 거절'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${business.businessName}을(를) 거절하시겠습니까?'),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: '거절 사유',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement rejection functionality
              Navigator.pop(context);
            },
            child: const Text('거절'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
