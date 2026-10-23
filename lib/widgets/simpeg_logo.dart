import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Logo bergaya kubus 4 warna, mendekati mark "simpeg" di desain asli.
/// Ini pendekatan visual, bukan aset asli instansi.
class SimpegLogo extends StatelessWidget {
  final double size;
  const SimpegLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final piece = size * 0.52;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: size * 0.02,
            top: size * 0.02,
            child: _diamond(piece, const Color(0xFFAEB8E8)),
          ),
          Positioned(
            right: size * 0.02,
            top: size * 0.02,
            child: _diamond(piece, const Color(0xFF8FD3A6)),
          ),
          Positioned(
            left: size * 0.02,
            bottom: size * 0.02,
            child: _diamond(piece, const Color(0xFFE79EAE)),
          ),
          Positioned(
            right: size * 0.02,
            bottom: size * 0.02,
            child: _diamond(piece, const Color(0xFF6C63D6)),
          ),
        ],
      ),
    );
  }

  Widget _diamond(double s, Color color) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: s * 0.62,
        height: s * 0.62,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}