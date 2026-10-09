import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/document_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bs_ui.dart';
import '../widgets/chain_steps.dart';

/// Verificar la autenticidad de un documento contra el contrato en Sepolia.
/// El archivo NUNCA sale del dispositivo: aquí se calcula su SHA-256 y solo
/// se consulta esa huella.
class VerifyScreen extends StatefulWidget {
  final String? initialHash;
  const VerifyScreen({super.key, this.initialHash});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

enum _Mode { file, hash }

class _VerifyScreenState extends State<VerifyScreen> {
  _Mode _mode = _Mode.file;
  final _hashCtrl = TextEditingController();

  // Proceso
  bool _running = false;
  String? _fileName;
  int? _fileSize;
  String? _hash;
  List<ChainStep> _steps = [];
  Map<String, dynamic>? _result;

  // Red
  Map<String, dynamic>? _network;
  bool _loadingNetwork = true;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
    if (widget.initialHash != null && widget.initialHash!.length == 64) {
      _mode = _Mode.hash;
      _hashCtrl.text = widget.initialHash!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyHash());
    }
  }

  @override
  void dispose() {
    _hashCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNetwork() async {
    setState(() => _loadingNetwork = true);
    final n = await DocumentService.getNetworkInfo();
    if (mounted) {
      setState(() {
        _network = n;
        _loadingNetwork = false;
      });
    }
  }

  Future<void> _pause([int ms = 380]) => Future.delayed(Duration(milliseconds: ms));

  void _setStep(int i, ChainStep step) {
    setState(() {
      if (i < _steps.length) {
        _steps[i] = step;
      } else {
        _steps.add(step);
      }
    });
  }

  // ── Archivo ────────────────────────────────────────────
  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    if (f.bytes == null) return;
    await _verifyBytes(f.name, f.bytes!);
  }

  Future<void> _verifyBytes(String name, Uint8List bytes) async {
    setState(() {
      _running = true;
      _result = null;
      _hash = null;
      _fileName = name;
      _fileSize = bytes.length;
      _steps = [];
    });

    _setStep(0, ChainStep('Leer archivo', state: ChainStepState.done, detail: '$name · ${_fmtSize(bytes.length)} · no se sube a ningún servidor'));
    _setStep(1, const ChainStep('Calcular huella SHA-256 en tu dispositivo', state: ChainStepState.active));
    await _pause(250);
    final hash = sha256.convert(bytes).toString();
    if (!mounted) return;
    _hash = hash;
    _setStep(
      1,
      ChainStep('Calcular huella SHA-256 en tu dispositivo',
          state: ChainStepState.done,
          detail: '64 caracteres que identifican este archivo exacto.',
          extra: [ChainValueRow(label: 'Huella', value: hash)]),
    );
    await _pause();
    await _queryChain(hash, offset: 2);
  }

  // ── Huella pegada ─────────────────────────────────────
  Future<void> _verifyHash() async {
    final h = _hashCtrl.text.trim().toLowerCase().replaceFirst(RegExp(r'^0x'), '');
    setState(() {
      _running = true;
      _result = null;
      _fileName = null;
      _fileSize = null;
      _hash = h;
      _steps = [];
    });
    final ok = RegExp(r'^[0-9a-f]{64}$').hasMatch(h);
    _setStep(
      0,
      ChainStep('Validar huella SHA-256',
          state: ok ? ChainStepState.done : ChainStepState.error,
          detail: ok ? 'Formato correcto (64 caracteres hexadecimales).' : 'Debe tener exactamente 64 caracteres 0-9 / a-f.',
          extra: [if (ok) ChainValueRow(label: 'Huella', value: h)]),
    );
    if (!ok) {
      setState(() => _running = false);
      return;
    }
    await _pause();
    await _queryChain(h, offset: 1);
  }

  // ── Consulta al servidor + blockchain ──────────────────
  Future<void> _queryChain(String hash, {required int offset}) async {
    _setStep(offset, const ChainStep('Consultar DocBlockSign y el contrato en Sepolia', state: ChainStepState.active,
        detail: 'Leyendo el registro inmutable del contrato…'));
    final res = await DocumentService.verifyByHash(hash);
    if (!mounted) return;

    if (res['error'] != null && res['verdict'] == null) {
      _setStep(offset, ChainStep('Consultar DocBlockSign y el contrato en Sepolia', state: ChainStepState.error, detail: res['error'].toString()));
      setState(() => _running = false);
      return;
    }

    // Quitamos el paso "consultando" y mostramos los pasos que hizo el servidor, uno a uno
    setState(() => _steps.removeAt(offset));
    final serverSteps = (res['steps'] as List? ?? []).where((s) => s is Map && s['key'] != 'hash').toList();
    var i = offset;
    for (final s in serverSteps) {
      final m = Map<String, dynamic>.from(s as Map);
      _setStep(i, ChainStep(m['label']?.toString() ?? '', state: ChainStepState.active));
      await _pause(420);
      if (!mounted) return;
      final ok = m['ok'] == true;
      final key = m['key'];
      // "No está en DocBlockSign" o "no está en el contrato" no son errores del sistema: son resultados.
      final softFail = !ok && (key == 'database');
      _setStep(
        i,
        ChainStep(
          m['label']?.toString() ?? '',
          state: ok ? ChainStepState.done : (softFail ? ChainStepState.waiting : ChainStepState.error),
          detail: m['detail']?.toString(),
          extra: _extraFor(key, res),
        ),
      );
      i++;
    }
    await _pause(250);
    if (!mounted) return;
    setState(() {
      _result = res;
      _running = false;
    });
  }

  List<Widget> _extraFor(dynamic key, Map<String, dynamic> res) {
    final tx = res['transaction'] is Map ? Map<String, dynamic>.from(res['transaction']) : null;
    final bc = res['blockchain'] is Map ? Map<String, dynamic>.from(res['blockchain']) : null;
    if (key == 'blockchain' && bc != null) {
      return [
        if (bc['contractAddress'] != null)
          ChainValueRow(label: 'Contrato', value: bc['contractAddress'].toString(), url: bc['contractUrl']?.toString()),
      ];
    }
    if (key == 'transaction' && tx != null && tx['txHash'] != null) {
      return [ChainValueRow(label: 'Tx', value: tx['txHash'].toString(), url: tx['explorerUrl']?.toString())];
    }
    return const [];
  }

  void _reset() {
    setState(() {
      _steps = [];
      _result = null;
      _hash = null;
      _fileName = null;
      _fileSize = null;
      _hashCtrl.clear();
    });
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w > 600 ? 28.0 : 16.0;
    final twoCols = w > 1250;

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _inputCard(),
      if (_steps.isNotEmpty) ...[
        const SizedBox(height: 16),
        BSCard(
          title: _running ? 'Verificando…' : 'Comprobaciones realizadas',
          trailing: _running
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
              : Text(
                  '${_steps.where((x) => x.state == ChainStepState.done).length} de ${_steps.length} correctas',
                  style: TextStyle(
                    color: _steps.any((x) => x.state == ChainStepState.error) ? BSColors.danger : BSColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          child: ChainTimeline(steps: _steps),
        ),
      ],
      if (_result != null) ...[
        const SizedBox(height: 16),
        _VerdictCard(result: _result!, fileName: _fileName, onReset: _reset),
      ],
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _NetworkCard(info: _network, loading: _loadingNetwork, onRefresh: _loadNetwork),
      const SizedBox(height: 16),
      const _HowItWorksCard(),
      const SizedBox(height: 16),
      const BSInfoBanner(
        title: 'Verificación pública',
        text: 'Quien recibe un documento por correo puede verificarlo con este mismo flujo, sin crear una cuenta.',
        icon: Icons.public_rounded,
      ),
    ]);

    return Container(
      color: BSColors.page,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BSPageHeader(
            breadcrumb: const ['Inicio', 'Verificar'],
            title: 'Verificar documento',
            subtitle: 'Comprueba que un archivo es auténtico y que nadie lo modificó desde que se firmó.',
            badges: [
              BSPill(
                label: _network?['connected'] == true ? 'Sepolia en línea' : (_loadingNetwork ? 'Conectando…' : 'Sin conexión'),
                color: _network?['connected'] == true ? BSColors.success : (_loadingNetwork ? BSColors.neutral : BSColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (twoCols)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: side),
            ])
          else ...[
            main,
            const SizedBox(height: 16),
            side,
          ],
        ]),
      ),
    );
  }

  Widget _inputCard() {
    return BSCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _ModeSwitch(mode: _mode, onChanged: _running ? null : (m) => setState(() => _mode = m)),
        const SizedBox(height: 16),
        if (_mode == _Mode.file) _dropZone() else _hashInput(),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: BSColors.success),
          SizedBox(width: 6),
          Expanded(
            child: Text('Privado: el archivo no se sube. Solo se envía su huella SHA-256.',
                style: TextStyle(color: AppTheme.hint, fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _dropZone() {
    final picked = _fileName != null;
    return InkWell(
      onTap: _running ? null : _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.35), width: 1.4),
        ),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(picked ? Icons.description_rounded : Icons.upload_file_rounded, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            picked ? _fileName! : 'Selecciona el documento a verificar',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            picked ? '${_fmtSize(_fileSize ?? 0)} · toca para elegir otro' : 'PDF, Word o cualquier archivo firmado con DocBlockSign',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.hint, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          BSPrimaryButton(
            label: _running ? 'Verificando…' : (picked ? 'Elegir otro archivo' : 'Elegir archivo'),
            icon: Icons.folder_open_rounded,
            loading: _running,
            onPressed: _pickFile,
          ),
        ]),
      ),
    );
  }

  Widget _hashInput() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Huella SHA-256 del documento', style: TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        controller: _hashCtrl,
        enabled: !_running,
        maxLength: 66,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-FxX]'))],
        onSubmitted: (_) => _verifyHash(),
        decoration: InputDecoration(
          hintText: 'Ej: 3f7a9c…(64 caracteres)',
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          suffixIcon: IconButton(
            tooltip: 'Pegar',
            icon: const Icon(Icons.content_paste_rounded, size: 18),
            onPressed: _running
                ? null
                : () async {
                    final d = await Clipboard.getData('text/plain');
                    if (d?.text != null) _hashCtrl.text = d!.text!.trim();
                  },
          ),
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: BSPrimaryButton(label: 'Verificar huella', icon: Icons.verified_outlined, loading: _running, onPressed: _verifyHash),
      ),
    ]);
  }
}

String _fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
}

// ── Selector Archivo / Huella ──────────────────────────────
class _ModeSwitch extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode>? onChanged;
  const _ModeSwitch({required this.mode, this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(_Mode m, IconData icon, String label) {
      final sel = m == mode;
      return Expanded(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(m),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 1))] : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: sel ? AppTheme.primary : AppTheme.hint),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: sel ? AppTheme.primary : AppTheme.hint, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
              ),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        seg(_Mode.file, Icons.upload_file_rounded, 'Subir archivo'),
        const SizedBox(width: 4),
        seg(_Mode.hash, Icons.tag_rounded, 'Pegar huella'),
      ]),
    );
  }
}

// ── Veredicto ──────────────────────────────────────────────
class _VerdictCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final String? fileName;
  final VoidCallback onReset;
  const _VerdictCard({required this.result, this.fileName, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final verdict = result['verdict']?.toString() ?? 'not_registered';
    final (Color color, IconData icon, String title) = switch (verdict) {
      'authentic' => (BSColors.success, Icons.verified_rounded, 'Documento auténtico'),
      'revoked' => (BSColors.danger, Icons.gpp_bad_rounded, 'Firma revocada'),
      'invalid_signature' => (BSColors.danger, Icons.gpp_bad_rounded, 'Firma digital inválida'),
      'pending' => (BSColors.warning, Icons.hourglass_top_rounded, 'Firma en proceso'),
      'unavailable' => (BSColors.warning, Icons.cloud_off_rounded, 'Blockchain no disponible'),
      'invalid' => (BSColors.danger, Icons.error_outline_rounded, 'Huella inválida'),
      _ => (BSColors.danger, Icons.help_outline_rounded, 'Sin registro en blockchain'),
    };

    final bc = result['blockchain'] is Map ? Map<String, dynamic>.from(result['blockchain']) : null;
    final tx = result['transaction'] is Map ? Map<String, dynamic>.from(result['transaction']) : null;
    final doc = result['document'] is Map ? Map<String, dynamic>.from(result['document']) : null;
    final wide = MediaQuery.of(context).size.width > 720;

    final sig = result['signature'] is Map ? Map<String, dynamic>.from(result['signature']) : null;
    final details = <(String, String)>[
      if (bc?['documentTitle'] != null) ('Documento', bc!['documentTitle'].toString()),
      if (doc?['signerName'] != null) ('Firmado por', doc!['signerName'].toString()),
      if (bc?['signerEmail'] != null) ('Correo del firmante', bc!['signerEmail'].toString()),
      if (bc?['signedAt'] != null) ('Fecha de registro', chainDate(bc!['signedAt'].toString())),
      if (tx?['blockNumber'] != null) ('Bloque', '#${tx!['blockNumber']}'),
      if (tx?['confirmations'] != null) ('Confirmaciones', '${tx!['confirmations']}'),
      ('Verificado', chainDate(result['checkedAt']?.toString())),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Banda superior
        Container(
          padding: const EdgeInsets.all(20),
          color: color.withOpacity(0.07),
          child: Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(result['message']?.toString() ?? '', style: const TextStyle(color: AppTheme.text, fontSize: 13, height: 1.4)),
                if (fileName != null) ...[
                  const SizedBox(height: 6),
                  Text('Archivo: $fileName',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.hint, fontSize: 12)),
                ],
              ]),
            ),
          ]),
        ),
        // Detalles
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (details.length > 1) ...[
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  for (final d in details)
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.$1, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(d.$2, style: const TextStyle(color: AppTheme.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (result['hash'] != null) ChainValueRow(label: 'Huella', value: result['hash'].toString()),
            if (bc?['signatureHash'] != null) ChainValueRow(label: 'Firma', value: bc!['signatureHash'].toString()),
            if (sig?['fingerprint'] != null) ChainValueRow(label: 'Clave pública', value: sig!['fingerprint'].toString()),
            if (sig?['algorithm'] != null) ChainValueRow(label: 'Algoritmo', value: sig!['algorithm'].toString(), mono: false, copy: false, shorten: false),
            if (bc?['signerWallet'] != null) ChainValueRow(label: 'Wallet', value: bc!['signerWallet'].toString()),
            if (tx?['txHash'] != null) ChainValueRow(label: 'Tx', value: tx!['txHash'].toString(), url: tx['explorerUrl']?.toString()),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
              if (tx?['explorerUrl'] != null)
                BSOutlineButton(label: 'Ver en Etherscan', icon: Icons.open_in_new_rounded, onPressed: () => openExternal(tx!['explorerUrl'].toString())),
              BSPrimaryButton(label: 'Verificar otro', icon: Icons.refresh_rounded, onPressed: onReset),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Estado de la red ───────────────────────────────────────
class _NetworkCard extends StatelessWidget {
  final Map<String, dynamic>? info;
  final bool loading;
  final VoidCallback onRefresh;
  const _NetworkCard({required this.info, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final ok = info?['connected'] == true;
    return BSCard(
      title: 'Red blockchain',
      trailing: IconButton(
        tooltip: 'Actualizar',
        onPressed: loading ? null : onRefresh,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
            : const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.hint),
      ),
      child: loading && info == null
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : !ok
              ? BSInfoBanner(
                  title: 'Sin conexión con Sepolia',
                  text: info?['error']?.toString() ?? 'Revisa que el backend esté corriendo.',
                  color: BSColors.danger,
                  icon: Icons.cloud_off_rounded,
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    _Stat(label: 'Bloque actual', value: '#${info!['latestBlock']}'),
                    const SizedBox(width: 10),
                    _Stat(label: 'Documentos', value: '${info!['totalDocuments'] ?? '—'}'),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _Stat(label: 'Red', value: '${info!['network']} (${info!['chainId']})'),
                    const SizedBox(width: 10),
                    _Stat(
                      label: 'Gas',
                      value: info!['gasPriceGwei'] != null ? '${double.tryParse(info!['gasPriceGwei'].toString())?.toStringAsFixed(2)} gwei' : '—',
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (info!['contractAddress'] != null)
                    ChainValueRow(label: 'Contrato', value: info!['contractAddress'].toString(), url: info!['contractUrl']?.toString()),
                  if (info!['wallet'] != null) ChainValueRow(label: 'Wallet', value: info!['wallet'].toString()),
                  if (info!['balanceEth'] != null)
                    ChainValueRow(
                      label: 'Saldo',
                      value: '${double.tryParse(info!['balanceEth'].toString())?.toStringAsFixed(4)} ETH',
                      mono: false,
                      copy: false,
                    ),
                ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: BSColors.page, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppTheme.hint, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ── Cómo funciona ──────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: AppTheme.hint, fontSize: 12, height: 1.4)),
              ]),
            ),
          ]),
        );
    return BSCard(
      title: '¿Cómo funciona?',
      child: Column(children: [
        item(Icons.fingerprint_rounded, 'Huella única', 'Se calcula el SHA-256 del archivo. Si cambia un solo byte, la huella es otra.'),
        item(Icons.link_rounded, 'Registro inmutable', 'Al firmar, la huella se guarda en un contrato de Ethereum (Sepolia) que nadie puede editar.'),
        item(Icons.search_rounded, 'Comprobación', 'Verificar consulta el contrato: si la huella existe y la firma sigue vigente, el documento es auténtico.'),
      ]),
    );
  }
}
