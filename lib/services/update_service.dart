import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Actualizaciones de la app de Android (fuera de Play Store).
///
/// Cada APK lleva su número de compilación (BUILD_NUMBER, el número de la
/// compilación en GitHub Actions). Al abrir la app se consulta la última
/// versión publicada en GitHub Releases; si es mayor, se ofrece descargarla.
/// Como todas las versiones se firman con la misma llave, Android la instala
/// encima de la anterior sin perder nada.
class UpdateService {
  static const int currentBuild = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
  static const _releasesApi =
      'https://api.github.com/repos/JuanDpf26/Signatures_BlockChain_Project_B-F/releases?per_page=20';

  static bool get _enabled => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && currentBuild > 0;

  /// Devuelve {build, url} de la versión más nueva, o null si no hay una mayor.
  static Future<({int build, String url})?> latest() async {
    if (!_enabled) return null;
    try {
      final res = await http
          .get(Uri.parse(_releasesApi), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      int best = 0;
      String? url;
      for (final r in (jsonDecode(res.body) as List)) {
        final m = RegExp(r'^apk-prueba-(\d+)$').firstMatch('${r['tag_name']}');
        if (m == null) continue;
        final n = int.parse(m.group(1)!);
        if (n <= best) continue;
        final assets = (r['assets'] as List?) ?? [];
        // Preferimos el APK liviano (arm64); si no está, el universal
        Map? a = assets.cast<Map?>().firstWhere((x) => '${x?['name']}'.contains('arm64'), orElse: () => null);
        a ??= assets.cast<Map?>().firstWhere((x) => '${x?['name']}'.endsWith('.apk'), orElse: () => null);
        if (a == null) continue;
        best = n;
        url = '${a['browser_download_url']}';
      }
      if (url == null || best <= currentBuild) return null;
      return (build: best, url: url);
    } catch (_) {
      return null; // sin internet o GitHub no responde: no se molesta al usuario
    }
  }

  /// Muestra el aviso si hay una versión nueva. Devuelve cuando el usuario decide.
  static Future<void> checkAndPrompt(BuildContext context) async {
    final upd = await latest();
    if (upd == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 28),
        ),
        title: const Text('Nueva versión disponible', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.text)),
        content: Text(
          'Hay una versión más reciente de DocBlockSign (compilación ${upd.build}; tienes la $currentBuild).\n\n'
          'Se descargará el instalador; ábrelo y pulsa "Actualizar". No perderás tu sesión ni tus documentos.',
          style: const TextStyle(color: AppTheme.hint, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Más tarde')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              await launchUrl(Uri.parse(upd.url), mode: LaunchMode.externalApplication);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
