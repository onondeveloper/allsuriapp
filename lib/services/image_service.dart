import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ImageService extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  // 이미지 선택
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // 여러 이미지 선택
  Future<List<File>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }

  // 이미지 압축 (임시 구현)
  Future<File?> compressImage(File file) async {
    try {
      // 임시로 원본 파일 반환 (실제 압축 로직은 나중에 구현)
      return file;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  // 이미지를 바이트로 변환
  Future<Uint8List?> imageToBytes(File file) async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      print('Error converting image to bytes: $e');
      return null;
    }
  }

  // 임시 디렉토리에 이미지 저장
  Future<String?> saveImageToTemp(File file) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final String filePath = path.join(tempDir.path, fileName);
      
      await file.copy(filePath);
      return filePath;
    } catch (e) {
      print('Error saving image to temp: $e');
      return null;
    }
  }

  // 이미지 업로드 (임시 구현)
  Future<String?> uploadImage(File file) async {
    try {
      // 임시로 로컬 경로 반환 (실제 업로드 로직은 나중에 구현)
      return await saveImageToTemp(file);
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  // 이미지 크기 조정 (임시 구현)
  Future<File?> resizeImage(File file, {int? maxWidth, int? maxHeight}) async {
    try {
      // 임시로 원본 파일 반환 (실제 리사이즈 로직은 나중에 구현)
      return file;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }

  Future<String?> pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;
    // 실제 업로드 없이 임시로 파일 경로 반환
    return pickedFile.path;
  }
} 