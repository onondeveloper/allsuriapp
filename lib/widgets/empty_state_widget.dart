import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Empty State 위젯
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? lottieAsset;
  final IconData? icon;
  final String? actionButtonText;
  final VoidCallback? onActionPressed;
  final double imageSize;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.lottieAsset,
    this.icon,
    this.actionButtonText,
    this.onActionPressed,
    this.imageSize = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 일러스트 또는 아이콘
            if (lottieAsset != null)
              SizedBox(
                width: imageSize,
                height: imageSize,
                child: Lottie.asset(
                  lottieAsset!,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              )
            else if (icon != null)
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: imageSize * 0.5,
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                ),
              )
            else
              Icon(
                Icons.inbox_outlined,
                size: imageSize * 0.7,
                color: Colors.grey[400],
              ),

            const SizedBox(height: 32),

            // 제목
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // 메시지
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),

            // 액션 버튼
            if (actionButtonText != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(actionButtonText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 특화된 Empty State 위젯들

/// 오더 목록이 비었을 때
class EmptyOrdersWidget extends StatelessWidget {
  final VoidCallback? onBrowseOrders;

  const EmptyOrdersWidget({Key? key, this.onBrowseOrders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: '새로운 오더를 기다리고 있어요!',
      message: '곧 새로운 공사 오더가 올라올 거예요.\n조금만 기다려주세요!',
      icon: Icons.schedule_outlined,
      actionButtonText: '새로고침',
      onActionPressed: onBrowseOrders,
    );
  }
}

/// 공사 목록이 비었을 때
class EmptyJobsWidget extends StatelessWidget {
  const EmptyJobsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: '진행 중인 공사가 없어요',
      message: '오더에 입찰하고 낙찰되면\n여기에 공사가 표시됩니다',
      icon: Icons.construction_outlined,
    );
  }
}

/// 채팅 목록이 비었을 때
class EmptyChatWidget extends StatelessWidget {
  const EmptyChatWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: '채팅 내역이 없어요',
      message: '오더를 낙찰받으면\n고객과 채팅을 시작할 수 있어요',
      icon: Icons.chat_bubble_outline,
    );
  }
}

/// 알림 목록이 비었을 때
class EmptyNotificationWidget extends StatelessWidget {
  const EmptyNotificationWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: '알림이 없어요',
      message: '새로운 오더나 메시지가 오면\n여기에 알림이 표시됩니다',
      icon: Icons.notifications_none,
      imageSize: 150,
    );
  }
}

/// 검색 결과가 없을 때
class EmptySearchResultWidget extends StatelessWidget {
  final String searchQuery;

  const EmptySearchResultWidget({
    Key? key,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: '검색 결과가 없어요',
      message: '"$searchQuery"에 대한\n검색 결과를 찾을 수 없습니다',
      icon: Icons.search_off,
      imageSize: 150,
    );
  }
}

/// 견적 요청이 없을 때
class EmptyEstimateRequestWidget extends StatelessWidget {
  const EmptyEstimateRequestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: '견적 요청이 없어요',
      message: '고객의 견적 요청이 들어오면\n여기에 표시됩니다',
      icon: Icons.description_outlined,
    );
  }
}

/// 리뷰가 없을 때
class EmptyReviewWidget extends StatelessWidget {
  const EmptyReviewWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: '아직 리뷰가 없어요',
      message: '공사를 완료하면\n고객이 리뷰를 남길 수 있어요',
      icon: Icons.star_outline,
      imageSize: 150,
    );
  }
}

