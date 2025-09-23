import 'package:flutter/cupertino.dart';

class StarRating extends StatelessWidget {
  final double rating; // 0.0 ~ 5.0
  final int starCount;
  final double size;
  final Color filledColor;
  final Color emptyColor;
  final EdgeInsetsGeometry padding;

  const StarRating({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.filledColor = const Color(0xFFFFC107),
    this.emptyColor = const Color(0xFFCBD5E1),
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final stars = List<Widget>.generate(starCount, (index) {
      final threshold = index + 1;
      final isFilled = rating >= threshold - 0.25; // simple threshold
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
          size: size,
          color: isFilled ? filledColor : emptyColor,
        ),
      );
    });
    return Padding(
      padding: padding,
      child: Row(children: stars),
    );
  }
}

class StarRatingInput extends StatefulWidget {
  final double initial;
  final ValueChanged<double> onRated;
  final int starCount;
  final double size;
  final Color filledColor;
  final Color emptyColor;

  const StarRatingInput({
    super.key,
    required this.initial,
    required this.onRated,
    this.starCount = 5,
    this.size = 28,
    this.filledColor = const Color(0xFFFFC107),
    this.emptyColor = const Color(0xFFCBD5E1),
  });

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  late double _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial.clamp(0, widget.starCount).toDouble();
  }

  void _set(double value) {
    setState(() => _current = value);
    widget.onRated(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(widget.starCount, (i) {
        final idx = i + 1;
        final isFilled = _current >= idx - 0.25;
        return GestureDetector(
          onTap: () => _set(idx.toDouble()),
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              isFilled ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: widget.size,
              color: isFilled ? widget.filledColor : widget.emptyColor,
            ),
          ),
        );
      }),
    );
  }
}


