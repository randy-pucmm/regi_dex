import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../themes/regi_theme.dart';
import '../tokens/contrast.dart';
import 'hexagon_border.dart';
import 'reduced_motion.dart';

/// Imagen de un Pokémon sobre una placa hexagonal del color de su tipo.
///
/// Se decodifica al tamaño de [size] (RNF-REN-04). Si la imagen no está en
/// la caché y no hay red, o no hay [url], muestra el respaldo: un retículo y
/// «Imagen no disponible offline».
class PokemonImage extends StatelessWidget {
  const PokemonImage({
    super.key,
    required this.url,
    required this.size,
    required this.cacheManager,
    this.plateColor,
    this.label,
  });

  final String? url;

  /// Alto del hexágono; la imagen ocupa un cuadrado de este lado.
  final double size;
  final BaseCacheManager cacheManager;

  /// Por defecto, el acento del tema.
  final Color? plateColor;

  /// Nombre del Pokémon, para el lector de pantalla.
  final String? label;

  /// Un hexágono regular con vértices arriba y abajo mide esto de ancho.
  static const _hexRatio = 0.866;

  /// Desde este alto el respaldo escribe «Imagen no disponible offline».
  static const captionMinSize = 200.0;

  @override
  Widget build(BuildContext context) {
    final plate = plateColor ?? RegiTheme.of(context).accent;
    final imageUrl = url;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final fallback = _Fallback(
      plate: plate,
      size: size,
      showCaption: size >= captionMinSize,
    );

    return Semantics(
      image: true,
      label: label,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size * _hexRatio,
              height: size,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: plate,
                  shape: const HexagonBorder(),
                ),
              ),
            ),
            if (imageUrl == null)
              fallback
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                cacheManager: cacheManager,
                width: size,
                height: size,
                memCacheWidth: pixels,
                memCacheHeight: pixels,
                fit: BoxFit.contain,
                fadeInDuration: reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => fallback,
              ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.plate,
    required this.size,
    required this.showCaption,
  });

  final Color plate;
  final double size;
  final bool showCaption;

  static const _message = 'Imagen no disponible offline';

  @override
  Widget build(BuildContext context) {
    final width = size * PokemonImage._hexRatio;
    // Con texto, el retículo se encoge para que ambos quepan en la placa.
    final side = showCaption ? size * .6 : width;
    final reticle = ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: _ReticlePainter(Color.lerp(plate, Colors.black, .62)!),
      ),
    );

    if (!showCaption) return Semantics(label: _message, child: reticle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        reticle,
        SizedBox(
          width: width * .8,
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: readableOn(plate)),
          ),
        ),
      ],
    );
  }
}

/// Retículo: anillo con cuatro marcas y un anillo discontinuo en el centro.
class _ReticlePainter extends CustomPainter {
  _ReticlePainter(this.color);

  final Color color;

  static const _dashes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = size.center(Offset.zero);
    final stroke = w * .035;
    final ring = w * .27;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawCircle(center, ring, line);
    for (var i = 0; i < 4; i++) {
      final direction = Offset.fromDirection(i * math.pi / 2);
      canvas.drawLine(
        center + direction * ring,
        center + direction * (ring + w * .1),
        line,
      );
    }

    const step = 2 * math.pi / _dashes;
    final inner = Rect.fromCircle(center: center, radius: w * .115);
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(inner, i * step, step * .5, false, line);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}
