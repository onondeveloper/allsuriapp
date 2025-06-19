// TODO: 이미지 업로드 기능을 카카오 또는 자체 서버로 구현하세요.
// 현재는 Firebase Storage 관련 코드를 모두 삭제했습니다.

// import 'package:image_picker/image_picker.dart';

class StorageService {
  // final ImagePicker _picker = ImagePicker();

  // Future<List<String>> pickImages({int maxImages = 5}) async {
  //   try {
  //     final List<XFile> images = await _picker.pickMultiImage();
  //     if (images.isEmpty) return [];
  //     if (images.length > maxImages) {
  //       images.removeRange(maxImages, images.length);
  //     }
  //     return images.map((image) => image.path).toList();
  //   } catch (e) {
  //     throw Exception('이미지를 선택하는 중 오류가 발생했습니다: $e');
  //   }
  // }

  // Future<String> pickImage() async {
  //   try {
  //     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  //     if (image == null) throw Exception('이미지가 선택되지 않았습니다');
  //     return image.path;
  //   } catch (e) {
  //     throw Exception('이미지를 선택하는 중 오류가 발생했습니다: $e');
  //   }
  // }

  // TODO: 이미지 업로드 기능은 나중에 추가 예정
} 