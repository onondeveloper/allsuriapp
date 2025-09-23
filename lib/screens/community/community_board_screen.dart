import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/community_service.dart';
import '../../models/community_post.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class CommunityBoardScreen extends StatefulWidget {
  const CommunityBoardScreen({super.key});

  @override
  State<CommunityBoardScreen> createState() => _CommunityBoardScreenState();
}

class _CommunityBoardScreenState extends State<CommunityBoardScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CommunityPost> _posts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final svc = Provider.of<CommunityService>(context, listen: false);
      final rows = await svc.getPosts(query: _searchController.text.trim());
      setState(() => _posts = rows);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('사업자 커뮤니티')),
      child: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: '검색어를 입력하세요 (제목, 내용)',
                        onSubmitted: (_) => _refresh(),
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: _refresh,
                      child: const Text('검색', style: TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _posts.isEmpty
                            ? ListView(children: const [SizedBox(height: 200), Center(child: Text('게시글이 없습니다.'))])
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemBuilder: (_, idx) => _buildPostTile(_posts[idx]),
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemCount: _posts.length,
                              ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const CreatePostScreen()),
                        );
                        if (!mounted) return;
                        await _refresh();
                      },
                      child: const Text('새 글 작성', style: TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostTile(CommunityPost post) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
        );
        if (!mounted) return;
        await _refresh();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title, style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              post.content.length > 120 ? post.content.substring(0, 120) + '…' : post.content,
              style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: -8,
              children: [
                Text(_formatTime(post.createdAt), style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black)),
                Text('· 추천 ${post.upvotes}', style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black)),
                Text('· 댓글 ${post.commentsCount}', style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black)),
                if (post.tags.isNotEmpty)
                  ...post.tags.take(3).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('#$t', style: const TextStyle(fontFamily: 'Arial', fontSize: 15, color: CupertinoColors.black))
                      )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
