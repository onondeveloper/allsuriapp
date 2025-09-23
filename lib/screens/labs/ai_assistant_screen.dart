import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import 'dart:io';
import '../../services/media_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _questionCtrl = TextEditingController();
  bool _loading = false;
  final List<Map<String, dynamic>> _messages = []; // {role: 'assistant'|'user', text: String, time: DateTime}
  final ScrollController _scrollController = ScrollController();
  final List<File> _localImages = [];
  final MediaService _media = MediaService();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('AllSuri AI')),
      child: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black),
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text('현장 견적, 자재 추천, 시공 단계 등 무엇이든 물어보세요.'),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        reverse: true, // 질문(위) -> 답변(아래) 순으로 보이게 하단에 쌓이도록 변경
                        itemCount: _messages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser)
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: const Center(child: Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF6D28D9))),
                                )
                              else
                                const SizedBox(width: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isUser ? const Color(0xFFE0F2FE) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Text(msg['text'] as String),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: Border(top: BorderSide(color: CupertinoColors.separator)),
        ),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: _loading ? null : _pickImage,
              child: const Icon(CupertinoIcons.photo, size: 22),
            ),
            Expanded(
              child: CupertinoTextField(
                controller: _questionCtrl,
                placeholder: '질문을 입력하세요 (예: 욕실 배관 교체 견적 범위?)',
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loading ? null : _ask,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _loading ? CupertinoColors.systemGrey2 : CupertinoColors.activeBlue,
                  shape: BoxShape.circle,
                ),
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : const Icon(CupertinoIcons.paperplane_fill, color: CupertinoColors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty && _localImages.isEmpty) return;
    setState(() {
      _loading = true;
      _messages.add({'role': 'user', 'text': q, 'time': DateTime.now()});
    });
    try {
      // Upload selected images to get public URLs
      final List<String> urls = [];
      for (final file in _localImages) {
        final url = await _media.uploadAiImage(file: file);
        if (url != null) urls.add(url);
      }

      final uri = Uri.parse('${ApiService.baseUrl}/ai/ask');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': q, 'images': urls}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final answer = (data['answer']?.toString() ?? '').trim();
        setState(() {
          _messages.add({'role': 'assistant', 'text': answer.isEmpty ? '답변이 비어 있습니다.' : answer, 'time': DateTime.now()});
        });
      } else {
        String err = '오류: ${resp.statusCode}';
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          err += ' - ' + (body['message']?.toString() ?? '');
          if (body['details'] != null) err += '\n' + body['details'].toString();
        } catch (_) {
          err += ' ' + resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length);
        }
        setState(() {
          _messages.add({'role': 'assistant', 'text': err, 'time': DateTime.now()});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': '네트워크 오류: $e', 'time': DateTime.now()});
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      setState(() => _localImages.clear());
    }
  }

  Future<void> _pickImage() async {
    final file = await _media.pickImageFromGallery();
    if (file == null) return;
    setState(() {
      _localImages.add(file);
    });
  }

}
