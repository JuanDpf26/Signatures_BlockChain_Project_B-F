import 'package:flutter/material.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'sweet_alert.dart';

/// Enviar un documento por correo desde la plataforma.
/// Devuelve true si se envió.
Future<bool> showSendDocumentDialog(BuildContext context, Map<String, dynamic> doc) async {
  final wide = MediaQuery.of(context).size.width >= 720;
  final panel = _SendPanel(doc: doc);
  final r = wide
      ? await showDialog<bool>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760), child: panel),
          ),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(height: MediaQuery.of(ctx).size.height * 0.9, child: panel),
          ),
        );
  return r == true;
}

class _SendPanel extends StatefulWidget {
  final Map<String, dynamic> doc;
  const _SendPanel({required this.doc});

  @override
  State<_SendPanel> createState() => _SendPanelState();
}

class _SendPanelState extends State<_SendPanel> {
  static final _emailRe = RegExp(r'^[^\s@<>()\[\]\\,;:"]+@[^\s@<>()\[\]\\,;:"]+\.[a-zA-Z]{2,}$');

  final _toCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _toFocus = FocusNode();
  final List<String> _to = [];
  bool _attach = true;
  bool _sending = false;
  String? _toError;

  Map<String, dynamic> get _meta => Map<String, dynamic>.from((widget.doc['metadata'] as Map?) ?? {});
  String get _title => widget.doc['title']?.toString() ?? 'Documento';
  bool get _signed => ['signed', 'verified'].contains(widget.doc['status']);
  bool get _isPdf => (_meta['extension'] ?? 'pdf').toString().toLowerCase() == 'pdf';

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  /// Toma lo escrito (puede venir separado por comas o espacios) y lo vuelve chips
  bool _commit() {
    final parts = _toCtrl.text.split(RegExp(r'[,;\s]+')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty);
    final bad = <String>[];
    for (final p in parts) {
      if (!_emailRe.hasMatch(p)) {
        bad.add(p);
      } else if (!_to.contains(p) && _to.length < 5) {
        _to.add(p);
      }
    }
    setState(() {
      _toError = bad.isNotEmpty
          ? 'Revisa: ${bad.join(', ')}'
          : (_to.length >= 5 ? 'Máximo 5 destinatarios por envío' : null);
      _toCtrl.text = bad.join(' ');
    });
    return bad.isEmpty;
  }

  Future<void> _send() async {
    if (!_commit()) return;
    if (_to.isEmpty) {
      setState(() => _toError = 'Escribe al menos un correo');
      _toFocus.requestFocus();
      return;
    }
    setState(() => _sending = true);
    final res = await DocumentService.sendByEmail(
      docId: widget.doc['id'].toString(),
      recipients: _to,
      subject: _subjectCtrl.text,
      message: _msgCtrl.text,
      attach: _attach,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.containsKey('error')) {
      await SweetAlert.error(context, title: 'No se pudo enviar', text: res['error'].toString());
      return;
    }
    Navigator.of(context).pop(true);
    final note = res['note']?.toString();
    SweetAlert.success(
      context,
      title: res['message']?.toString() ?? 'Documento enviado',
      text: [
        (res['sent_to'] as List?)?.join('\n') ?? _to.join('\n'),
        if (note != null && note.isNotEmpty) note,
      ].join('\n\n'),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.6)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final hash = widget.doc['file_hash']?.toString() ?? '';
    final shortHash = hash.length > 24 ? '${hash.substring(0, 12)}…${hash.substring(hash.length - 8)}' : hash;
    final shares = ((_meta['shares'] as List?) ?? const []).whereType<Map>().take(3).toList();
    final tint = _isPdf ? BSColors.danger : AppTheme.primary;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Encabezado azul
      Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.forward_to_inbox_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enviar por correo', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Se envía desde BlockSign con la huella y el enlace para verificarlo', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          IconButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ]),
      ),

      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 12), children: [
          // Documento
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_isPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('${_meta['size_mb'] ?? '?'} MB · $shortHash',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.hint, fontSize: 12, fontFamily: 'monospace')),
                ]),
              ),
              const SizedBox(width: 8),
              BSPill(label: _signed ? 'Firmado' : 'Sin firmar', color: _signed ? BSColors.success : BSColors.warning),
            ]),
          ),
          const SizedBox(height: 18),

          // Para
          _label('Para'),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _toError != null ? BSColors.danger : AppTheme.border, width: _toError != null ? 1.4 : 1),
            ),
            child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final e in _to)
                InputChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.primary),
                  label: Text(e),
                  onDeleted: _sending ? null : () => setState(() => _to.remove(e)),
                  deleteIconColor: AppTheme.primary,
                  backgroundColor: BSColors.selected,
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
                  labelStyle: const TextStyle(color: AppTheme.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  visualDensity: VisualDensity.compact,
                ),
              SizedBox(
                width: 230,
                child: TextField(
                    controller: _toCtrl,
                    focusNode: _toFocus,
                    enabled: !_sending && _to.length < 5,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (v) {
                      if (v.endsWith(',') || v.endsWith(' ') || v.endsWith(';')) _commit();
                    },
                    onSubmitted: (_) {
                      _commit();
                      _toFocus.requestFocus();
                    },
                    onTapOutside: (_) {
                      if (_toCtrl.text.trim().isNotEmpty) _commit();
                    },
                    style: const TextStyle(color: AppTheme.text, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: _to.isEmpty ? 'correo@ejemplo.com y Enter' : (_to.length < 5 ? 'Agregar otro…' : ''),
                      hintStyle: const TextStyle(color: AppTheme.hint, fontSize: 13.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    ),
                  ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _toError ?? 'Hasta 5 personas. Separa con coma o Enter.',
              style: TextStyle(color: _toError != null ? BSColors.danger : AppTheme.hint, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          _label('Asunto (opcional)'),
          TextField(
            controller: _subjectCtrl,
            enabled: !_sending,
            maxLength: 150,
            style: const TextStyle(color: AppTheme.text, fontSize: 13.5),
            decoration: _dec('Te compartieron "$_title"').copyWith(counterText: ''),
          ),
          const SizedBox(height: 16),

          _label('Mensaje (opcional)'),
          TextField(
            controller: _msgCtrl,
            enabled: !_sending,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.45),
            decoration: _dec('Ej.: Te envío el contrato firmado para tu revisión.'),
          ),
          const SizedBox(height: 6),

          // Adjuntar
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              value: _attach,
              onChanged: _sending ? null : (v) => setState(() => _attach = v),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
              title: const Text('Adjuntar el archivo', style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(
                _attach ? 'Va como adjunto (hasta 15 MB).' : 'Se envía un enlace de descarga en lugar del archivo.',
                style: const TextStyle(color: AppTheme.hint, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          BSInfoBanner(
            title: _signed ? 'Podrán verificar que es auténtico' : 'Aún no está firmado',
            text: _signed
                ? 'El correo incluye el bloque, la transacción y un enlace para verificarlo en BlockSign sin crear cuenta.'
                : 'El correo incluye su huella SHA-256. Si lo firmas antes de enviarlo, podrán comprobar en blockchain que nadie lo modificó.',
            color: _signed ? BSColors.success : BSColors.warning,
            icon: _signed ? Icons.verified_rounded : Icons.info_outline_rounded,
          ),
          if (shares.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Enviado antes', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final s in shares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.mark_email_read_outlined, size: 16, color: AppTheme.hint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(((s['to'] as List?) ?? const []).join(', '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.text, fontSize: 12.5)),
                  ),
                  Text(_ago(s['at']?.toString()), style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                ]),
              ),
          ],
        ]),
      ),

      // Pie
      Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          Expanded(
            child: Text(
              _to.isEmpty ? 'Sin destinatarios' : '${_to.length} destinatario${_to.length == 1 ? '' : 's'}',
              style: const TextStyle(color: AppTheme.hint, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          const SizedBox(width: 8),
          BSPrimaryButton(
            label: _sending ? 'Enviando…' : 'Enviar',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _send,
          ),
        ]),
      ),
    ]);
  }

  static String _ago(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return '${t.day}/${t.month}/${t.year}';
  }
}
