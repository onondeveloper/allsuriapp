import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;
  const ShimmerCard({super.key, this.height = 90, this.margin = const EdgeInsets.only(bottom: 12)});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
      highlightColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      child: Container(
        height: height,
        width: double.infinity,
        margin: margin,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  const ShimmerList({super.key, this.itemCount = 4, this.itemHeight = 90});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, __) => ShimmerCard(height: itemHeight),
    );
  }
}


