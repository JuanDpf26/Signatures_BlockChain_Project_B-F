import 'dart:convert';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Para no repetir el aviso en la misma sesión (lo pueden pedir el splash y el inicio)
  static bool _shown = false;

  /// Muestra el aviso si hay una versión nueva (una sola vez por sesión).
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_shown) return;
    final upd = await latest();
    if (upd == null || !context.mounted || _shown) return;
    await prompt(context, upd);
  }

  /// Muestra el aviso para una versión ya consultada.
  static Future<void> prompt(BuildContext context, ({int build, String url}) upd) async {
    _shown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(upd: upd),
    );
  }

  /// Descarga el APK dentro de la app y abre el instalador de Android.
  /// [onProgress] recibe de 0 a 1 (o null si no se conoce el tamaño).
  static Future<String?> downloadAndInstall(String url, int build, void Function(double?) onProgress) async {
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) return 'El servidor respondió ${res.statusCode}';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/DocBlockSign-$build.apk');
      final sink = file.openWrite();
      final total = res.contentLength ?? 0;
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(total > 0 ? got / total : null);
      }
      await sink.close();
      final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (r.type == ResultType.done) return null;
      if (r.type == ResultType.permissionDenied) {
        return 'Android pidió permiso para instalar. Activa "Permitir de esta fuente" para DocBlockSign y vuelve a pulsar Actualizar.';
      }
      return r.message;
    } catch (e) {
      return 'No se pudo descargar la actualización ($e)';
    } finally {
      client.close();
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final ({int build, String url}) upd;
  const _UpdateDialog({required this.upd});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double? _progress;
  String? _error;

  Future<void> _update() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    final err = await UpdateService.downloadAndInstall(widget.upd.url, widget.upd.build, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    if (err == null) {
      // El instalador de Android quedó abierto con el botón "Actualizar"
      Navigator.of(context).pop();
    } else {
      setState(() {
        _downloading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _progress == null ? null : (_progress! * 100).round();
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 28),
      ),
      title: Text(_downloading ? 'Descargando actualización…' : 'Nueva versión disponible',
          textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.text)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          _downloading
              ? 'Cuando termine se abrirá el instalador: pulsa "Actualizar". Tus documentos no se pierden.'
              : 'Hay una versión más reciente de DocBlockSign (${widget.upd.build}; tienes la ${UpdateService.currentBuild}). '
                  'Se instala encima de la actual, sin volver a descargarla desde el navegador.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.hint, height: 1.4),
        ),
        if (_downloading) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _progress, minHeight: 8, color: AppTheme.primary, backgroundColor: AppTheme.border),
          ),
          const SizedBox(height: 8),
          Text(pct == null ? 'Descargando…' : '$pct %', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13, height: 1.4)),
        ],
      ]),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: _downloading
          ? null
          : [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Más tarde')),
              if (_error != null)
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(widget.upd.url), mode: LaunchMode.externalApplication),
                  child: const Text('Descargar en el navegador'),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: _update,
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
    );
  }
}
