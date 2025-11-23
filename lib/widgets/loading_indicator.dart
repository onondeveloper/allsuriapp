import 'package:flutter/material.dart';
import '../config/app_constants.dart';

/// E-commerce 스타일의 로딩 인디케이터 위젯
/// 
/// 사용 예시:
/// ```dart
/// body: _isLoading
///   ? const LoadingIndicator(message: '데이터를 불러오는 중...')
///   : YourContent(),
/// ```
class LoadingIndicator extends StatelessWidget {
  final String message;
  final String? subtitle;
  final Color? progressColor;
  final double? size;

  const LoadingIndicator({
    super.key,
    this.message = '로딩 중...',
    this.subtitle,
    this.progressColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final containerSize = size ?? 80.0;
    final progressSize = (size ?? 80.0) / 2;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // E-commerce 스타일의 CircularProgressIndicator
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (progressColor ?? AppConstants.primaryColor).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: progressSize,
                height: progressSize,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? AppConstants.primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 작은 인라인 로딩 인디케이터
class SmallLoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const SmallLoadingIndicator({
    super.key,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppConstants.primaryColor,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 버튼 내부용 작은 로딩 인디케이터
class ButtonLoadingIndicator extends StatelessWidget {
  final Color color;
  final double size;

  const ButtonLoadingIndicator({
    super.key,
    this.color = Colors.white,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

