import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';

class CommunityService extends ChangeNotifier {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<CommunityPost>> getPosts({String? query, int limit = 50}) async {
    try {
      var sel = _sb.from('community_posts').select();
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        sel = sel.or('title.ilike.%$q%,content.ilike.%$q%');
      }
      final rows = await sel.order('createdat', ascending: false).limit(limit);
      return rows.map<CommunityPost>((r) => CommunityPost.fromMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<CommunityPost?> getPost(String id) async {
    try {
      final row = await _sb.from('community_posts').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return CommunityPost.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<CommunityPost?> createPost({
    required String authorId,
    required String title,
    required String content,
    List<String>? tags,
  }) async {
    try {
      final payload = {
        'authorid': authorId,
        'title': title,
        'content': content,
        if (tags != null) 'tags': tags,
        'createdat': DateTime.now().toIso8601String(),
      };
      final inserted = await _sb.from('community_posts').insert(payload).select().single();
      return CommunityPost.fromMap(Map<String, dynamic>.from(inserted));
    } catch (e) {
      debugPrint('createPost error: $e');
      return null;
    }
  }

  Future<void> upvotePost(String postId) async {
    try {
      await _sb.rpc('increment_post_upvotes', params: {'post_id': postId});
    } catch (e) {
      // fallback: naive update
      try {
        final current = await _sb.from('community_posts').select('upvotes').eq('id', postId).single();
        final up = int.tryParse((current['upvotes'] ?? 0).toString()) ?? 0;
        await _sb.from('community_posts').update({'upvotes': up + 1}).eq('id', postId);
      } catch (_) {}
    }
  }

  Future<List<CommunityComment>> getComments(String postId) async {
    try {
      final rows = await _sb
          .from('community_comments')
          .select()
          .eq('postid', postId)
          .order('createdat', ascending: true);
      return rows.map<CommunityComment>((r) => CommunityComment.fromMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<CommunityComment?> addComment({
    required String postId,
    required String authorId,
    required String content,
  }) async {
    try {
      final payload = {
        'postid': postId,
        'authorid': authorId,
        'content': content,
        'createdat': DateTime.now().toIso8601String(),
      };
      final row = await _sb.from('community_comments').insert(payload).select().single();
      // best-effort: increment comments count
      try {
        await _sb.rpc('increment_post_comments', params: {'post_id': postId});
      } catch (_) {}
      return CommunityComment.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('addComment error: $e');
      return null;
    }
  }
}
