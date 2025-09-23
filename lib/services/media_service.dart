import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _sb = Supabase.instance.client;

  static const int maxBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedExt = ['.jpg', '.jpeg', '.png', '.heic'];

  Future<File?> pickImageFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return null;
    final file = File(x.path);
    return _validate(file) ? file : null;
  }

  Future<File?> pickImageFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return null;
    final file = File(x.path);
    return _validate(file) ? file : null;
  }

  bool _validate(File file) {
    try {
      final size = file.lengthSync();
      if (size > maxBytes) {
        debugPrint('파일 용량 초과: ${size}B');
        return false;
      }
      final ext = p.extension(file.path).toLowerCase();
      if (!allowedExt.contains(ext)) {
        debugPrint('허용되지 않은 확장자: $ext');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('파일 검증 실패: $e');
      return false;
    }
  }

  Future<String?> uploadProfileImage({required String userId, required File file}) async {
    try {
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final path = 'profiles/$userId/$fileName';
      await _sb.storage.from('profiles').upload(path, file);
      final publicUrl = _sb.storage.from('profiles').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('프로필 업로드 실패: $e');
      return null;
    }
  }

  Future<String?> uploadMessageImage({required String roomId, required String userId, required File file}) async {
    try {
      final fileName = 'msg_${userId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final path = 'attachments_messages/$roomId/$fileName';
      await _sb.storage.from('attachments_messages').upload(path, file);
      final publicUrl = _sb.storage.from('attachments_messages').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('메시지 이미지 업로드 실패: $e');
      return null;
    }
  }

  Future<String?> uploadAiImage({required File file}) async {
    try {
      final fileName = 'ai_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      // Reuse existing bucket to avoid new bucket provisioning
      final path = 'ai/$fileName';
      await _sb.storage.from('attachments_messages').upload(path, file);
      final publicUrl = _sb.storage.from('attachments_messages').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('AI 이미지 업로드 실패: $e');
      return null;
    }
  }
}


