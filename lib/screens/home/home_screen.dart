import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
// import '../../providers/auth_provider.dart'; // 인증 기능을 사용하지 않으므로 주석 처리
import '../../models/order.dart';
import '../../models/role.dart';
import '../order/create_order_screen.dart';
import '../order/my_orders_page.dart';
import '../order/order_detail_screen.dart';
import '../chat/chat_list_page.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserRole userRole;
  const HomeScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late String _currentUserId;
  late String _currentUserRole;

  @override
  void initState() {
    super.initState();
    _currentUserRole = widget.userRole.toString().split('.').last;
    _currentUserId = 'user_${DateTime.now().millisecondsSinceEpoch}'; // 임시 ID 생성
    // 주문 목록 로드
    context.read<OrderProvider>().loadOrders(customerId: _currentUserId);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return MyOrdersPage(
          currentUserId: _currentUserId,
          currentUserRole: _currentUserRole,
        );
      case 2:
        return const ChatListPage();
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orderProvider.error != null) {
          return Center(child: Text('에러: ${orderProvider.error}'));
        }

        if (orderProvider.orders.isEmpty) {
          return const Center(child: Text('주문이 없습니다.'));
        }

        return RefreshIndicator(
          onRefresh: () => context.read<OrderProvider>().loadOrders(customerId: _currentUserId),
          child: ListView.builder(
            itemCount: orderProvider.orders.length,
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              return _buildOrderCard(order);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(order.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.description),
            const SizedBox(height: 4),
            Text('주소: ${order.address}'),
            Text('상태: ${order.status}'),
          ],
        ),
        trailing: Text('${order.estimatedPrice.toStringAsFixed(0)}원'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(
                order: order,
                currentUserId: _currentUserId,
                currentUserRole: _currentUserRole,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('올수리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateOrderScreen(
                    customerId: _currentUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '내 주문',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '채팅',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateOrderScreen(customerId: _currentUserId),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '견적 추가',
      ),
    );
  }
} 