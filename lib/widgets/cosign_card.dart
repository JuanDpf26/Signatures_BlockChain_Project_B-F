import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/collab_service.dart';
import '../services/cosign_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'proof_ui.dart' show fmtFechaHora;
import 'sweet_alert.dart';

/// Firma con varios firmantes: quién firma, en qué orden y en qué va.
/// La usan el detalle del documento (dueño) y la bandeja (firmantes).
class CosignCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic>? cosign;
  final bool isOwner;
  final bool docPending; // aún no firmado ni registrándose
  final String? chainStatus; // metadata.blockchain_status
  final String? chainError;
  final VoidCallback onChanged;

  const CosignCard({
    super.key,
    required this.docId,
    required this.cosign,
    required this.isOwner,
    required this.docPending,
    required this.onChanged,
    this.chainStatus,
    this.chainError,
  });

  @override
  State<CosignCard> createState() => _CosignCardState();
}

class _CosignCardState extends State<CosignCard> {
  String? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AuthService.currentUserId().then((id) {
      if (mounted) setState(() => _me = id);
    });
  }

  List<Map<String, dynamic>> get _signers =>
      ((widget.cosign?['signers'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  String get _status => widget.cosign?['status']?.toString() ?? '';

  Map<String, dynamic>? get _current {
    for (final s in _signers) {
      if (s['status'] == 'pending') return s;
    }
    return null;
  }

  bool get _myTurn => _status == 'collecting' && _me != null && _current?['user_id']?.toString() == _me;

  Future<void> _run(Future<Map<String, dynamic>> Function() call, {String? ok}) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r['error'] != null) {
      await SweetAlert.error(context, title: 'No se pudo completar', text: r['error'].toString());
      return;
    }
    if (r['chainError'] != null) {
      await SweetAlert.warning(context, title: 'Firmas completas', text: '${r['message']}\n\n${r['chainError']}');
    } else {
      showToast(context, title: ok ?? r['message']?.toString() ?? 'Listo');
    }
    widget.onChanged();
  }

  Future<void> _request() async {
    final res = await showDialog<(List<String>, String)>(context: context, builder: (_) => const _RequestDialog());
    if (res == null || !mounted) return;
    await _run(() => CosignService.request(widget.docId, res.$1, message: res.$2), ok: 'Solicitud enviada. Le avisamos al primer firmante.');
  }

  Future<void> _sign() async {
    final ok = await SweetAlert.confirm(
      context,
      title: 'Firmar documento',
      text: 'Se firma con tu llave personal y tu firma manuscrita. Cuando firmen todos, el documento queda registrado en blockchain.',
      confirmText: 'Firmar',
    );
    if (!ok || !mounted) return;
    await _run(() => CosignService.respond(widget.docId, sign: true));
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('No firmar', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cuéntale al dueño del documento por qué no lo firmas. La solicitud se detiene para todos.',
                style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Motivo (obligatorio)', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BSColors.danger),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('No firmar'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _run(() => CosignService.respond(widget.docId, sign: false, comment: reason));
  }

  Future<void> _cancel() async {
    final ok = await SweetAlert.confirm(
      context,
      type: SweetAlertType.warning,
      danger: true,
      title: 'Cancelar la solicitud',
      text: 'Las firmas que ya se hicieron se descartan y nadie más podrá firmar esta solicitud.',
      confirmText: 'Sí, cancelar',
    );
    if (!ok || !mounted) return;
    await _run(() => CosignService.cancel(widget.docId), ok: 'Solicitud cancelada');
  }

  @override
  Widget build(BuildContext context) {
    final signers = _signers;
    final active = _status == 'collecting' || _status == 'completed';

    // Sin solicitud (o la anterior terminó sin éxito): ofrecer crear una
    if (!active) {
      if (!widget.isOwner || !widget.docPending) return const SizedBox.shrink();
      return BSCard(
        title: 'Firma de varias personas',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_status == 'rejected') ...[
            _rejectedBanner(signers),
            const SizedBox(height: 12),
          ],
          Text(
            '¿Este documento lo deben firmar varias personas? Elige quiénes y en qué orden. Cada una firma con su propia llave y, cuando firme la última, se registra en blockchain.',
            style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: BSOutlineButton(
              label: _status == 'rejected' || _status == 'cancelled' ? 'Hacer una nueva solicitud' : 'Pedir firmas',
              icon: Icons.group_add_outlined,
              onPressed: _busy ? null : _request,
            ),
          ),
        ]),
      );
    }

    final done = signers.where((s) => s['status'] == 'signed').length;
    final total = signers.length;
    final chainFailed = _status == 'completed' && widget.chainStatus == 'failed';

    return BSCard(
      title: 'Firmantes',
      trailing: Text('$done de $total', style: TextStyle(color: AppTheme.hint, fontSize: 13, fontWeight: FontWeight.w600)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 6,
            color: BSColors.success,
            backgroundColor: AppTheme.border,
          ),
        ),
        const SizedBox(height: 12),
        for (final s in signers) _SignerRow(signer: s, isMe: s['user_id']?.toString() == _me),
        if ((widget.cosign?['message']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Mensaje: “${widget.cosign!['message']}”', style: TextStyle(color: AppTheme.hint, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
        if (_myTurn) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BSColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BSColors.success.withOpacity(0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Te toca firmar', style: TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Revisa el documento antes. Tu firma queda guardada con tu llave personal.',
                  style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: BSOutlineButton(label: 'No firmar', icon: Icons.close_rounded, color: BSColors.danger, onPressed: _busy ? null : _reject)),
                const SizedBox(width: 10),
                Expanded(child: BSPrimaryButton(label: 'Firmar', icon: Icons.draw_rounded, color: BSColors.success, loading: _busy, onPressed: _sign)),
              ]),
            ]),
          ),
        ] else if (_status == 'collecting' && _current != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 16, color: AppTheme.hint),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Esperando la firma de ${_current!['name'] ?? _current!['email']}',
                  style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            ),
          ]),
        ],
        if (_status == 'completed') ...[
          const SizedBox(height: 12),
          chainFailed
              ? BSInfoBanner(
                  title: 'Firmaron todos, falta el registro',
                  text: widget.chainError ?? 'El registro en blockchain no se completó.',
                  color: BSColors.warning,
                  icon: Icons.warning_amber_rounded,
                )
              : BSInfoBanner(
                  title: 'Firmaron todos',
                  text: widget.chainStatus == 'confirmed'
                      ? 'La huella de todas las firmas quedó registrada en blockchain.'
                      : 'Registrando la huella de todas las firmas en blockchain…',
                  color: BSColors.success,
                  icon: Icons.verified_rounded,
                ),
        ],
        if (widget.isOwner && (_status == 'collecting' || chainFailed)) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (chainFailed)
              BSPrimaryButton(
                label: 'Registrar en blockchain',
                icon: Icons.link_rounded,
                loading: _busy,
                onPressed: () => _run(() => CosignService.retryRegister(widget.docId), ok: 'Registrando en blockchain…'),
              ),
            if (_status == 'collecting')
              BSOutlineButton(label: 'Cancelar solicitud', icon: Icons.cancel_outlined, color: BSColors.danger, onPressed: _busy ? null : _cancel),
          ]),
        ],
      ]),
    );
  }

  Widget _rejectedBanner(List<Map<String, dynamic>> signers) {
    final who = signers.where((s) => s['status'] == 'rejected').toList();
    final s = who.isEmpty ? null : who.first;
    return BSInfoBanner(
      title: s == null ? 'La solicitud anterior no se completó' : '${s['name'] ?? s['email']} no firmó',
      text: (s?['comment']?.toString().isNotEmpty == true) ? '“${s!['comment']}”' : 'Puedes ajustar el documento y pedir las firmas otra vez.',
      color: BSColors.danger,
      icon: Icons.cancel_rounded,
    );
  }
}

class _SignerRow extends StatelessWidget {
  final Map<String, dynamic> signer;
  final bool isMe;
  const _SignerRow({required this.signer, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final st = signer['status']?.toString();
    final (Color c, IconData icon, String label) = switch (st) {
      'signed' => (BSColors.success, Icons.check_rounded, 'Firmó'),
      'pending' => (AppTheme.primary, Icons.edit_rounded, 'Le toca'),
      'rejected' => (BSColors.danger, Icons.close_rounded, 'No firmó'),
      'cancelled' => (BSColors.neutral, Icons.remove_rounded, 'Cancelado'),
      _ => (BSColors.neutral, Icons.more_horiz_rounded, 'En espera'),
    };
    final name = (signer['name'] ?? signer['email']).toString();
    final when = signer['signed_at']?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: st == 'signed' || st == 'rejected' ? c : AppTheme.card,
            border: Border.all(color: c, width: 2),
          ),
          child: st == 'signed' || st == 'rejected'
              ? Icon(icon, size: 16, color: Colors.white)
              : Text('${signer['position']}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? '$name (tú)' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.text, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(
              [signer['email'], if (when != null) fmtFechaHora(when)].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.hint, fontSize: 12),
            ),
          ]),
        ),
        BSPill(label: label, color: c, dot: false),
      ]),
    );
  }
}

/// Elegir firmantes y su orden
class _RequestDialog extends StatefulWidget {
  const _RequestDialog();

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _email = TextEditingController();
  final _msg = TextEditingController();
  final List<(String email, String? name)> _list = [];
  List<Map<String, dynamic>> _suggest = [];
  Timer? _debounce;
  String? _myEmail;
  String? _myName;
  String? _error;

  static final _re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    ProfileService.getProfile().then((r) {
      final u = r['user'];
      if (u is Map && mounted) setState(() { _myEmail = u['email']?.toString().toLowerCase(); _myName = u['name']?.toString(); });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _email.dispose();
    _msg.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _suggest = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final r = await CollabService.searchUsers(q.trim());
      if (!mounted) return;
      setState(() => _suggest = ((r['users'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(5).toList());
    });
  }

  void _add(String email, [String? name]) {
    final e = email.trim().toLowerCase();
    if (!_re.hasMatch(e)) {
      setState(() => _error = 'Escribe un correo válido');
      return;
    }
    if (_list.any((x) => x.$1 == e)) {
      setState(() => _error = 'Ya está en la lista');
      return;
    }
    if (_list.length >= 10) {
      setState(() => _error = 'Máximo 10 firmantes');
      return;
    }
    setState(() {
      _list.add((e, name));
      _email.clear();
      _suggest = [];
      _error = null;
    });
  }

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= _list.length) return;
    setState(() {
      final t = _list[i];
      _list[i] = _list[j];
      _list[j] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final meIncluded = _myEmail != null && _list.any((x) => x.$1 == _myEmail);
    return AlertDialog(
      backgroundColor: AppTheme.card,
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      title: Text('Pedir firmas', style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Firman en este orden. A cada persona le avisamos cuando le toca, por la bandeja y por correo. Todas necesitan cuenta en DocBlockSign.',
                style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _search,
                  onSubmitted: (v) => _add(v),
                  decoration: InputDecoration(
                    hintText: 'Correo o nombre del firmante',
                    isDense: true,
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _add(_email.text), child: const Text('Agregar')),
            ]),
            for (final u in _suggest)
              ListTile(
                dense: true,
                leading: Icon(Icons.person_outline_rounded, color: AppTheme.primary),
                title: Text(u['name']?.toString() ?? u['email'].toString(), style: TextStyle(color: AppTheme.text, fontSize: 13)),
                subtitle: Text(u['email'].toString(), style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                onTap: () => _add(u['email'].toString(), u['name']?.toString()),
              ),
            if (_myEmail != null && !meIncluded)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _add(_myEmail!, _myName),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Incluirme como firmante'),
                ),
              ),
            const SizedBox(height: 8),
            if (_list.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10)),
                child: Text('Agrega al menos dos firmantes.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.hint, fontSize: 13)),
              )
            else
              for (var i = 0; i < _list.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    CircleAvatar(radius: 12, backgroundColor: AppTheme.primary, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _list[i].$1 == _myEmail ? '${_list[i].$2 ?? _list[i].$1} (tú)' : (_list[i].$2 ?? _list[i].$1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(tooltip: 'Subir', visualDensity: VisualDensity.compact, onPressed: i == 0 ? null : () => _move(i, -1), icon: const Icon(Icons.arrow_upward_rounded, size: 18)),
                    IconButton(tooltip: 'Bajar', visualDensity: VisualDensity.compact, onPressed: i == _list.length - 1 ? null : () => _move(i, 1), icon: const Icon(Icons.arrow_downward_rounded, size: 18)),
                    IconButton(tooltip: 'Quitar', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _list.removeAt(i)), icon: Icon(Icons.close_rounded, size: 18, color: BSColors.danger)),
                  ]),
                ),
            const SizedBox(height: 10),
            TextField(
              controller: _msg,
              maxLines: 2,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Mensaje para los firmantes (opcional)', border: OutlineInputBorder(), isDense: true),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _list.length < 2 ? null : () => Navigator.pop(context, (_list.map((e) => e.$1).toList(), _msg.text)),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text(_list.length < 2 ? 'Enviar solicitud' : 'Pedir ${_list.length} firmas'),
        ),
      ],
    );
  }
}

/// Descarga / abre el PDF con sello, QR y certificado
Future<void> openSignedPdf(BuildContext context, String docId) async {
  showToast(context, title: 'Preparando el PDF firmado…', type: SweetAlertType.info, duration: const Duration(seconds: 6));
  final r = await CosignService.signedPdf(docId);
  if (!context.mounted) return;
  if (r['url'] == null) {
    await SweetAlert.error(context, title: 'No se pudo generar', text: (r['error'] ?? 'Intenta de nuevo').toString());
    return;
  }
  await launchUrl(Uri.parse(r['url'].toString()), mode: LaunchMode.externalApplication);
}
