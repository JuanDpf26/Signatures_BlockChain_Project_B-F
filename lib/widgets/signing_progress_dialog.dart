import 'dart:async';
import 'package:flutter/material.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import 'bs_ui.dart';
import 'chain_steps.dart';

/// Muestra en vivo cómo se firma un documento y se registra en Sepolia.
/// Devuelve true si la firma quedó confirmada en un bloque.
Future<bool> showSigningProgress(BuildContext context, {required String docId, required String docTitle}) async {
  final wide = MediaQuery.of(context).size.width >= 700;
  final content = SigningProgressPanel(docId: docId, docTitle: docTitle);
  final r = wide
      ? await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760), child: content),
          ),
        )
      : await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            child: SafeArea(top: false, child: content),
          ),
        );
  return r == true;
}

enum _Phase { preparing, sending, confirming, confirmed, failed, slow }

class SigningProgressPanel extends StatefulWidget {
  final String docId;
  final String docTitle;
  const SigningProgressPanel({super.key, required this.docId, required this.docTitle});

  @override
  State<SigningProgressPanel> createState() => _SigningProgressPanelState();
}

class _SigningProgressPanelState extends State<SigningProgressPanel> {
  _Phase _phase = _Phase.preparing;
  int _visualStep = 0; // para animar los primeros pasos uno a uno
  String? _documentHash;
  String? _signatureHash;
  String? _txHash;
  String? _explorerUrl;
  String? _wallet;
  String? _error;
  Map<String, dynamic>? _tx; // estado de la transacción (bloque, gas…)

  final _started = DateTime.now();
  DateTime _pollStart = DateTime.now();
  Timer? _clock;
  Timer? _poll;
  bool _polling = false;

  static const _maxWait = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _run();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pause(int ms) => Future.delayed(Duration(milliseconds: ms));

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.preparing;
      _visualStep = 0;
      _error = null;
    });

    final res = await DocumentService.signDocument(widget.docId);
    if (!mounted) return;

    if (res['error'] != null) {
      setState(() {
        _phase = _Phase.failed;
        _error = res['error'].toString();
      });
      return;
    }

    _documentHash = res['documentHash']?.toString();
    _signatureHash = res['signatureHash']?.toString();
    _txHash = res['txHash']?.toString();
    _explorerUrl = res['explorerUrl']?.toString();
    _wallet = res['from']?.toString();

    // El servidor ya hizo estos pasos; los mostramos en orden para que se entienda el proceso.
    for (var i = 1; i <= 3; i++) {
      await _pause(550);
      if (!mounted) return;
      setState(() => _visualStep = i);
    }
    setState(() => _phase = _Phase.confirming);
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _pollStart = DateTime.now();
    _checkStatus();
    _poll = Timer.periodic(const Duration(milliseconds: 2500), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final st = await DocumentService.getSigningStatus(widget.docId);
      if (!mounted || (st['error'] != null && st['state'] == null)) return;
      final state = st['state']?.toString();
      setState(() {
        _documentHash ??= st['documentHash']?.toString();
        _signatureHash ??= st['signatureHash']?.toString();
        _txHash ??= st['txHash']?.toString();
        if (st['tx'] is Map) {
          _tx = Map<String, dynamic>.from(st['tx']);
          _explorerUrl ??= _tx!['explorerUrl']?.toString();
          _wallet ??= _tx!['from']?.toString();
        }
        if (_visualStep < 3 && _txHash != null) _visualStep = 3;
      });
      if (state == 'confirmed') {
        _poll?.cancel();
        setState(() => _phase = _Phase.confirmed);
      } else if (state == 'failed') {
        _poll?.cancel();
        setState(() {
          _phase = _Phase.failed;
          _error = st['error']?.toString() ?? 'La transacción no se pudo confirmar';
        });
      } else if (DateTime.now().difference(_pollStart) > _maxWait) {
        _poll?.cancel();
        setState(() => _phase = _Phase.slow);
      }
    } finally {
      _polling = false;
    }
  }

  // ── Pasos ──────────────────────────────────────────────
  ChainStepState _s(int i) {
    if (_phase == _Phase.failed) {
      final failedAt = _txHash != null ? 4 : (_visualStep >= 1 ? _visualStep : 0);
      if (i < failedAt) return ChainStepState.done;
      if (i == failedAt) return ChainStepState.error;
      return ChainStepState.waiting;
    }
    if (_phase == _Phase.confirmed) return ChainStepState.done;
    final waitingBlock = _phase == _Phase.confirming || _phase == _Phase.slow;
    final current = waitingBlock ? (_txIsMined ? 5 : 4) : _visualStep;
    if (i < current) return ChainStepState.done;
    if (i == current) return ChainStepState.active;
    return ChainStepState.waiting;
  }

  bool get _txIsMined => _tx?['state'] == 'confirmed';

  List<ChainStep> get _steps {
    final elapsed = chainElapsed(DateTime.now().difference(_started));
    final block = _tx?['blockNumber'];
    final latest = _tx?['latestBlock'];
    return [
      ChainStep(
        'Calcular huella del documento',
        state: _s(0),
        detail: _documentHash == null
            ? 'Validando el documento y tu firma registrada…'
            : 'SHA-256 del archivo: cualquier cambio, por mínimo que sea, la cambia por completo.',
        extra: [if (_documentHash != null) ChainValueRow(label: 'Huella', value: _documentHash!)],
      ),
      ChainStep(
        'Generar firma digital',
        state: _s(1),
        detail: _s(1) == ChainStepState.waiting ? null : 'Se combina la huella con tu identidad y la fecha exacta.',
        extra: [if (_signatureHash != null && _visualStep >= 1) ChainValueRow(label: 'Firma', value: _signatureHash!)],
      ),
      ChainStep(
        'Preparar transacción',
        state: _s(2),
        detail: _s(2) == ChainStepState.waiting ? null : 'Llamada a signDocument() del contrato, firmada por la wallet de BlockSign.',
        extra: [if (_wallet != null && _visualStep >= 2) ChainValueRow(label: 'Wallet', value: _wallet!)],
      ),
      ChainStep(
        'Enviar a la red Sepolia',
        state: _s(3),
        detail: _s(3) == ChainStepState.waiting ? null : 'La transacción ya está en la red esperando a ser incluida en un bloque.',
        extra: [
          if (_txHash != null && _visualStep >= 3) ChainValueRow(label: 'Tx', value: _txHash!, url: _explorerUrl),
        ],
      ),
      ChainStep(
        _txIsMined || _phase == _Phase.confirmed ? 'Incluida en el bloque #${block ?? '—'}' : 'Esperando confirmación del bloque',
        state: _s(4),
        detail: _phase == _Phase.failed && _txHash != null
            ? _error
            : _txIsMined || _phase == _Phase.confirmed
                ? 'Minada el ${chainDate(_tx?['minedAt']?.toString())}'
                : _s(4) == ChainStepState.active
                    ? 'Los validadores de Sepolia suelen tardar 12–30 s · llevas $elapsed${latest != null ? ' · bloque actual #$latest' : ''}'
                    : null,
        extra: [
          if (_tx?['gasUsed'] != null) ChainValueRow(label: 'Gas usado', value: '${_tx!['gasUsed']}', mono: false, copy: false),
          if (_tx?['feeEth'] != null) ChainValueRow(label: 'Costo', value: '${_tx!['feeEth']} ETH (prueba)', mono: false, copy: false),
        ],
      ),
      ChainStep(
        'Firma registrada',
        state: _s(5),
        detail: _phase == _Phase.confirmed ? 'El documento quedó firmado de forma inmutable. Cualquiera puede verificarlo con su huella.' : null,
      ),
    ];
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final failed = _phase == _Phase.failed;
    final done = _phase == _Phase.confirmed;
    final headColor = failed ? BSColors.danger : done ? BSColors.success : AppTheme.primary;
    final headTitle = failed
        ? 'No se pudo completar la firma'
        : done
            ? 'Documento firmado en blockchain'
            : _phase == _Phase.slow
                ? 'La red está tardando más de lo normal'
                : 'Firmando en blockchain…';

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Encabezado
      Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: headColor.withOpacity(0.06),
          border: Border(bottom: BorderSide(color: headColor.withOpacity(0.15))),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: headColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(
              failed ? Icons.error_outline_rounded : done ? Icons.verified_rounded : Icons.link_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headTitle, style: const TextStyle(color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(widget.docTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          const BSPill(label: 'Sepolia', color: AppTheme.featureCyan),
        ]),
      ),

      // Pasos
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChainTimeline(steps: _steps),
            if (failed && _txHash == null && _error != null) ...[
              const SizedBox(height: 12),
              BSInfoBanner(title: 'Detalle', text: _error!, color: BSColors.danger, icon: Icons.info_outline_rounded),
            ],
            if (_phase == _Phase.slow) ...[
              const SizedBox(height: 12),
              const BSInfoBanner(
                title: 'Sigue en proceso',
                text: 'La transacción sigue en la red. Puedes cerrar esta ventana: el documento se marcará como firmado en cuanto se confirme.',
                color: BSColors.warning,
                icon: Icons.schedule_rounded,
              ),
            ],
          ]),
        ),
      ),

      // Acciones
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
          if (_explorerUrl != null && (done || _phase == _Phase.slow || _phase == _Phase.confirming))
            BSOutlineButton(label: 'Ver en Etherscan', icon: Icons.open_in_new_rounded, onPressed: () => openExternal(_explorerUrl!)),
          if (failed && _txHash == null)
            BSOutlineButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _run),
          if (_phase == _Phase.slow)
            BSOutlineButton(label: 'Seguir esperando', icon: Icons.hourglass_bottom_rounded, onPressed: () {
              setState(() => _phase = _Phase.confirming);
              _startPolling();
            }),
          if (done || failed || _phase == _Phase.slow)
            BSPrimaryButton(
              label: done ? 'Listo' : 'Cerrar',
              icon: done ? Icons.check_rounded : Icons.close_rounded,
              color: done ? BSColors.success : null,
              onPressed: () => Navigator.of(context).pop(done),
            )
          else
            const BSPrimaryButton(label: 'Procesando…', loading: true),
        ]),
      ),
    ]);
  }
}
