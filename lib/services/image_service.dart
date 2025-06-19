import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:uuid/uuid.dart';
import '../config/aws_config.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final S3 _s3;

  ImageService()
      : _s3 = S3(
          region: AwsConfig.s3Region,
        );

  Future<List<String>> pickAndUploadImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return [];

      List<String> uploadedUrls = [];
      for (var image in images) {
        final compressedImage = await compressImage(File(image.path));
        if (compressedImage != null) {
          final url = await uploadImageToS3(compressedImage);
          if (url != null) {
            uploadedUrls.add(url);
          }
        }
      }
      return uploadedUrls;
    } catch (e) {
      print('Error picking images: $e');
      return [];
    }
  }

  Future<File?> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      
      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<String?> uploadImageToS3(File file) async {
    try {
      final fileName = '${const Uuid().v4()}.jpg';
      final bytes = await file.readAsBytes();

      await _s3.putObject(
        bucket: AwsConfig.s3Bucket,
        key: fileName,
        body: bytes,
        contentType: 'image/jpeg',
      );

      return 'https://${AwsConfig.s3Bucket}.s3.${AwsConfig.s3Region}.amazonaws.com/$fileName';
    } catch (e) {
      print('Error uploading image to S3: $e');
      return null;
    }
  }
} 