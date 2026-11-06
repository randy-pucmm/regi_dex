import 'package:flutter/material.dart';

/// Borde hexagonal. Con [Axis.vertical] los vértices quedan arriba y abajo; con
/// [Axis.horizontal], a los lados. [depth] es cuánto entra cada vértice.
class HexagonBorder extends OutlinedBorder {
  const HexagonBorder({super.side, this.pointAxis = Axis.vertical, this.depth});

  final Axis pointAxis;
  final double? depth;

  Path _path(Rect rect) {
    final l = rect.left, t = rect.top, w = rect.width, h = rect.height;
    if (pointAxis == Axis.horizontal) {
      final d = (depth ?? h / 2).clamp(0.0, w / 2);
      return Path()
        ..moveTo(l + d, t)
        ..lineTo(l + w - d, t)
        ..lineTo(l + w, t + h / 2)
        ..lineTo(l + w - d, t + h)
        ..lineTo(l + d, t + h)
        ..lineTo(l, t + h / 2)
        ..close();
    }
    final d = (depth ?? h / 4).clamp(0.0, h / 2);
    return Path()
      ..moveTo(l + w / 2, t)
      ..lineTo(l + w, t + d)
      ..lineTo(l + w, t + h - d)
      ..lineTo(l + w / 2, t + h)
      ..lineTo(l, t + h - d)
      ..lineTo(l, t + d)
      ..close();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      _path(rect.deflate(side.width / 2)),
      side.toPaint()..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  HexagonBorder copyWith({BorderSide? side, Axis? pointAxis, double? depth}) {
    return HexagonBorder(
      side: side ?? this.side,
      pointAxis: pointAxis ?? this.pointAxis,
      depth: depth ?? this.depth,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      HexagonBorder(side: side.scale(t), pointAxis: pointAxis, depth: depth);

  @override
  bool operator ==(Object other) =>
      other is HexagonBorder &&
      other.side == side &&
      other.pointAxis == pointAxis &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(side, pointAxis, depth);
}
