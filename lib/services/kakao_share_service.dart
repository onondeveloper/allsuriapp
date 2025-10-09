import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

/// 카카오톡 공유 서비스
/// 견적 요청을 카카오톡 메시지로 공유하는 기능 제공
class KakaoShareService {
  // 올수리 오픈채팅방 URL (실제 오픈채팅방 URL로 교체 필요)
  static const String openChatUrl = 'https://open.kakao.com/o/gv9woeWh';
  
  /// 견적 요청을 카카오톡으로 공유
  /// 
  /// [estimateId] 견적 요청 ID
  /// [title] 견적 요청 제목
  /// [category] 카테고리 (예: 누수, 보일러 등)
  /// [address] 주소
  /// [description] 설명 (선택)
  Future<bool> shareEstimate({
    required String estimateId,
    required String title,
    required String category,
    required String address,
    String? description,
  }) async {
    try {
      // 카카오톡 공유 템플릿 생성
      final template = FeedTemplate(
        content: Content(
          title: '🔧 $title',
          description: '''
카테고리: $category
주소: $address
${description != null && description.isNotEmpty ? '\n$description' : ''}

올수리 오픈채팅방에서 더 많은 사업자와 상담하세요!
''',
          imageUrl: Uri.parse('https://allsuri.app/assets/images/logo.png'),
          link: Link(
            // 앱 딥링크 (앱이 설치된 경우)
            androidExecutionParams: {'estimateId': estimateId},
            iosExecutionParams: {'estimateId': estimateId},
            // 웹 URL (앱 미설치 시)
            webUrl: Uri.parse('https://allsuri.app/estimate/$estimateId'),
            mobileWebUrl: Uri.parse('https://allsuri.app/estimate/$estimateId'),
          ),
        ),
        buttons: [
          Button(
            title: '오픈채팅방 참여하기',
            link: Link(
              webUrl: Uri.parse(openChatUrl),
              mobileWebUrl: Uri.parse(openChatUrl),
            ),
          ),
          Button(
            title: '앱에서 보기',
            link: Link(
              androidExecutionParams: {'estimateId': estimateId},
              iosExecutionParams: {'estimateId': estimateId},
              webUrl: Uri.parse('https://allsuri.app/estimate/$estimateId'),
              mobileWebUrl: Uri.parse('https://allsuri.app/estimate/$estimateId'),
            ),
          ),
        ],
      );

      // 카카오톡 설치 여부 확인
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        // 카카오톡으로 공유
        await ShareClient.instance.shareDefault(template: template);
        print('✅ 카카오톡 공유 성공');
        return true;
      } else {
        // 카카오톡 미설치 시 웹 공유 URL로 브라우저 열기
        final url = await WebSharerClient.instance.makeDefaultUrl(template: template);
        await launchUrl(url, mode: LaunchMode.externalApplication);
        print('✅ 웹 공유 URL 열기 성공');
        return true;
      }
    } catch (e) {
      print('❌ 카카오톡 공유 실패: $e');
      return false;
    }
  }

  /// 간단한 텍스트 메시지 공유 (오픈채팅방 링크만)
  Future<bool> shareOpenChatLink() async {
    try {
      final template = TextTemplate(
        text: '올수리 오픈채팅방에 참여하세요!\n집수리/인테리어 전문가들과 상담할 수 있습니다.',
        link: Link(
          webUrl: Uri.parse(openChatUrl),
          mobileWebUrl: Uri.parse(openChatUrl),
        ),
        buttons: [
          Button(
            title: '오픈채팅방 참여',
            link: Link(
              webUrl: Uri.parse(openChatUrl),
              mobileWebUrl: Uri.parse(openChatUrl),
            ),
          ),
        ],
      );

      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        await ShareClient.instance.shareDefault(template: template);
        return true;
      } else {
        final url = await WebSharerClient.instance.makeDefaultUrl(template: template);
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ 오픈채팅 링크 공유 실패: $e');
      return false;
    }
  }
}

