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

  Future<List<File>?> pickMultipleImages() async {
    // 현재 image_picker 버전에서는 pickMultipleImages를 지원하지 않으므로
    // 단일 이미지 선택으로 대체 (UI에서 여러 번 호출)
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return null;
    
    final file = File(image.path);
    if (_validate(file)) {
      return [file];
    }
    
    return null;
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
      final path = 'ai/$fileName';
      await _sb.storage.from('attachments_messages').upload(path, file);
      final publicUrl = _sb.storage.from('attachments_messages').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('AI 이미지 업로드 실패: $e');
      return null;
    }
  }

  Future<String?> uploadEstimateImage({required File file}) async {
    try {
      debugPrint('🔍 [uploadEstimateImage] 시작');
      debugPrint('   파일: ${file.path}');
      debugPrint('   파일 크기: ${file.lengthSync()} bytes');
      
      final fileName = 'job_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      debugPrint('   생성된 파일명: $fileName');
      
      final path = fileName;
      debugPrint('   경로: $path');
      debugPrint('   버킷: attachments_estimates');
      
      debugPrint('   → Supabase에 업로드 중...');
      await _sb.storage.from('attachments_estimates').upload(path, file);
      debugPrint('   ✅ 업로드 완료');
      
      debugPrint('   → Public URL 생성 중...');
      final publicUrl = _sb.storage.from('attachments_estimates').getPublicUrl(path);
      debugPrint('   ✅ Public URL: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      debugPrint('❌ [uploadEstimateImage] 실패: $e');
      return null;
    }
  }

  Future<String?> uploadAdImage(File file) async {
    try {
      debugPrint('🔍 [uploadAdImage] 시작');
      debugPrint('   파일: ${file.path}');
      debugPrint('   파일 크기: ${file.lengthSync()} bytes');
      
      final fileName = 'ad_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      debugPrint('   생성된 파일명: $fileName');
      
      final path = 'ads/$fileName';
      debugPrint('   경로: $path');
      debugPrint('   버킷: public');
      
      debugPrint('   → Supabase에 업로드 중...');
      await _sb.storage.from('public').upload(path, file);
      debugPrint('   ✅ 업로드 완료');
      
      debugPrint('   → Public URL 생성 중...');
      final publicUrl = _sb.storage.from('public').getPublicUrl(path);
      debugPrint('   ✅ Public URL: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      debugPrint('❌ [uploadAdImage] 실패: $e');
      return null;
    }
  }
}
