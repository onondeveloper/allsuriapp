import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_app_bar.dart';

class CreateOrderScreen extends StatefulWidget {
  final String customerId;

  const CreateOrderScreen({
    Key? key,
    required this.customerId,
  }) : super(key: key);

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTime _visitDate = DateTime.now();
  final List<String> _images = [];
  bool _isLoading = false;
  String _selectedCategory = '';
  List<String> _selectedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    print('_submitOrder called');
    print('Title: "${_titleController.text}"');
    print('Description: "${_descriptionController.text}"');
    print('Address: "${_addressController.text}"');

    if (_formKey.currentState == null) {
      print('Form key current state is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('폼 상태에 문제가 있습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필수 항목을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('Form validation passed');
    setState(() {
      _isLoading = true;
    });

    try {
      print('Creating order with customerId: ${widget.customerId}');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        address: _addressController.text,
        visitDate: _visitDate,
        status: Order.STATUS_PENDING,
        createdAt: DateTime.now(),
        estimatedPrice: double.tryParse(_budgetController.text) ?? 0.0,
        customerId: userProvider.currentUser?.id ?? '',
        customerName: userProvider.currentUser?.name ?? '',
        customerPhone: userProvider.currentUser?.phoneNumber ?? '',
        images: _selectedImages,
      );

      print('Order created: ${order.title}');

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      print('OrderProvider accessed successfully');

      await orderProvider.addOrder(order);
      print('Order added to provider successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적 요청이 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error creating order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주문 생성 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '견적 요청하기',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '제목',
                        hintText: '견적 요청 제목을 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '제목을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '설명',
                        hintText: '견적 요청에 대한 자세한 설명을 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '설명을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: '주소',
                        hintText: '작업이 필요한 주소를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '주소를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('방문 희망일'),
                      subtitle: Text(
                        '${_visitDate.year}년 ${_visitDate.month}월 ${_visitDate.day}일',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _visitDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          setState(() {
                            _visitDate = date;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    // 테스트용 버튼
                    ElevatedButton(
                      onPressed: () {
                        print('Test button pressed!');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('테스트 버튼이 눌렸습니다!')),
                        );
                      },
                      child: const Text('테스트 버튼'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          print('견적 요청하기 버튼이 눌렸습니다!');
                          _submitOrder();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '견적 요청하기',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
