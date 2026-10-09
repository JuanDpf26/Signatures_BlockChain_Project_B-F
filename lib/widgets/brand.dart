import 'package:flutter/material.dart';

/// Marca DocBlockSign: el cubo verificado y el nombre en tres tonos
/// (Doc · Block · Sign). Se usa en la barra lateral, el acceso y la carga.
class BrandSymbol extends StatelessWidget {
  final double size;

  /// true → versión clara para fondos azules u oscuros
  final bool onDark;
  const BrandSymbol({super.key, required this.size, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark ? 'assets/images/logo_simbolo_blanco.png' : 'assets/images/logo_simbolo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'DocBlockSign',
    );
  }
}

class BrandWordmark extends StatelessWidget {
  final double fontSize;
  final bool onDark;
  const BrandWordmark({super.key, required this.fontSize, this.onDark = false});

  static const _ink = Color(0xFF0F1B33);
  static const _blue = Color(0xFF0B45B5);
  static const _light = Color(0xFF3D7BEA);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: -0.6, height: 1.05);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Doc', style: TextStyle(color: onDark ? Colors.white : _ink)),
          TextSpan(text: 'Block', style: TextStyle(color: onDark ? const Color(0xFFCFE0FF) : _blue)),
          TextSpan(text: 'Sign', style: TextStyle(color: onDark ? const Color(0xFF8DB6FF) : _light)),
        ]),
        style: style,
        maxLines: 1,
      ),
    );
  }
}
