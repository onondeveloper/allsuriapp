import 'dart:math';
import 'package:flutter/material.dart';

/// 웨이브 패턴 페인터 (대시보드 배경용)
class WavePainter extends CustomPainter {
  final Color color;
  final double waveHeight;
  final double animationValue;

  WavePainter({
    required this.color,
    this.waveHeight = 20,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    // 첫 번째 웨이브
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height * 0.7 +
            sin((i / size.width * 2 * pi) + (animationValue * 2 * pi)) *
                waveHeight,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // 두 번째 웨이브 (투명도 추가)
    final paint2 = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);

    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(
        i,
        size.height * 0.75 +
            sin((i / size.width * 2 * pi) - (animationValue * 2 * pi) + pi) *
                (waveHeight * 0.8),
      );
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// 곡선형 구분선 페인터
class CurveDividerPainter extends CustomPainter {
  final Color color;
  final double curveHeight;

  CurveDividerPainter({
    required this.color,
    this.curveHeight = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height / 2);

    final controlPoint1 = Offset(size.width / 4, size.height / 2 - curveHeight);
    final controlPoint2 = Offset(size.width * 3 / 4, size.height / 2 + curveHeight);
    final endPoint = Offset(size.width, size.height / 2);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurveDividerPainter oldDelegate) => false;
}

/// 그라디언트 호(Arc) 페인터 (프로필 화면용)
class GradientArcPainter extends CustomPainter {
  final List<Color> colors;
  final double strokeWidth;
  final double progress; // 0.0 ~ 1.0

  GradientArcPainter({
    required this.colors,
    this.strokeWidth = 10,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = SweepGradient(
      colors: colors,
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(GradientArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 점선 원 페인터
class DottedCirclePainter extends CustomPainter {
  final Color color;
  final double dotRadius;
  final double gap;

  DottedCirclePainter({
    required this.color,
    this.dotRadius = 2,
    this.gap = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final circumference = 2 * pi * radius;
    final dotCount = (circumference / (dotRadius * 2 + gap)).floor();

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi / dotCount) * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(DottedCirclePainter oldDelegate) => false;
}

/// 체크 아이콘 애니메이션 페인터
class CheckPainter extends CustomPainter {
  final Color color;
  final double progress; // 0.0 ~ 1.0

  CheckPainter({
    required this.color,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // 체크 마크의 시작점
    final point1 = Offset(size.width * 0.2, size.height * 0.5);
    final point2 = Offset(size.width * 0.4, size.height * 0.7);
    final point3 = Offset(size.width * 0.8, size.height * 0.3);

    path.moveTo(point1.dx, point1.dy);
    
    if (progress < 0.5) {
      // 첫 번째 선 (절반까지)
      final t = progress * 2;
      path.lineTo(
        point1.dx + (point2.dx - point1.dx) * t,
        point1.dy + (point2.dy - point1.dy) * t,
      );
    } else {
      // 첫 번째 선 완료
      path.lineTo(point2.dx, point2.dy);
      
      // 두 번째 선 (절반부터 끝까지)
      final t = (progress - 0.5) * 2;
      path.lineTo(
        point2.dx + (point3.dx - point2.dx) * t,
        point2.dy + (point3.dy - point2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 배경 버블 패턴 페인터
class BubblePatternPainter extends CustomPainter {
  final Color color;
  final List<Offset> bubblePositions;
  final List<double> bubbleSizes;

  BubblePatternPainter({
    required this.color,
    required this.bubblePositions,
    required this.bubbleSizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < bubblePositions.length; i++) {
      final position = Offset(
        bubblePositions[i].dx * size.width,
        bubblePositions[i].dy * size.height,
      );
      final radius = bubbleSizes[i];
      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(BubblePatternPainter oldDelegate) => false;
}

