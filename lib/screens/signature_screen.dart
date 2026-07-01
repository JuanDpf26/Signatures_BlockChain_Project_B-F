import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import '../services/profile_service.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Canvas
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  final GlobalKey _canvasKey = GlobalKey();
  Color _strokeColor = const Color(0xFF1a1a2e);
  double _strokeWidth = 2.5;

  // Estado general
  String? _savedSignatureUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSignature();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSignature() async {
    setState(() => _isLoading = true);
    final res = await ProfileService.getSignature();
    if (!mounted) return;
    if (res.containsKey('signature')) {
      setState(() => _savedSignatureUrl = res['signature']['signature_url']);
    }
    setState(() => _isLoading = false);
  }

  // ── Canvas handlers ──
  void _onPanStart(DragStartDetails d) {
    _currentStroke = [d.localPosition];
    setState(() => _strokes.add(_currentStroke));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    _currentStroke.add(null);
  }

  void _clearCanvas() => setState(() {
        _strokes.clear();
        _currentStroke = [];
      });

  // ── Guardar firma desde canvas ──
  Future<void> _saveFromCanvas() async {
    if (_strokes.isEmpty) {
      showBS(context, 'Dibuja tu firma primero', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        showBS(context, 'Error al capturar la firma', isError: true);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';

      await _uploadSignature(base64Str);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Subir imagen de firma ──
  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isSaving = true);

      // Convertir a base64
      final mimeType = file.extension == 'png' ? 'image/png' : 'image/jpeg';
      final base64Str = 'data:$mimeType;base64,${base64Encode(file.bytes!)}';

      await _uploadSignature(base64Str);
    } catch (e) {
      if (mounted) showBS(context, 'Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadSignature(String base64Str) async {
    final res = await ProfileService.saveSignature(base64Str);
    if (!mounted) return;

    if (res.containsKey('error')) {
      showBS(context, res['error'], isError: true);
    } else {
      showBS(context, '✓ Firma guardada exitosamente');
      setState(() {
        _savedSignatureUrl = res['signature_url'];
        _strokes.clear();
        _currentStroke = [];
      });
    }
  }

  Future<void> _deleteSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar firma',
            style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700)),
        content: const Text('¿Estás seguro que deseas eliminar tu firma?',
            style: TextStyle(color: AppTheme.hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.hint))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ProfileService.deleteSignature();
    if (!mounted) return;
    if (res.containsKey('error')) {
      showBS(context, res['error'], isError: true);
    } else {
      showBS(context, 'Firma eliminada');
      setState(() => _savedSignatureUrl = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Firma guardada
          if (_savedSignatureUrl != null) ...[
            _SectionLabel('Firma actual'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      const Text('Firma registrada',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _deleteSignature,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 14),
                              SizedBox(width: 4),
                              Text('Eliminar',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _savedSignatureUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) => progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary)),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: AppTheme.hint),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 20),
            _SectionLabel('Actualizar firma'),
            const SizedBox(height: 4),
            const Text('Puedes dibujar una nueva firma o subir una imagen',
                style: TextStyle(color: AppTheme.hint, fontSize: 13)),
            const SizedBox(height: 16),
          ] else ...[
            _SectionLabel('Crear firma digital'),
            const SizedBox(height: 4),
            const Text(
                'Dibuja tu firma o sube una imagen PNG/JPG para usarla en tus documentos.',
                style: TextStyle(color: AppTheme.hint, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
          ],

          // Tabs: Dibujar / Subir imagen
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.hint,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  icon: Icon(Icons.draw_rounded, size: 18),
                  text: 'Dibujar firma',
                ),
                Tab(
                  icon: Icon(Icons.upload_file_rounded, size: 18),
                  text: 'Subir imagen',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB 1: Canvas ──
                Column(
                  children: [
                    // Toolbar
                    Row(
                      children: [
                        const Text('Color:',
                            style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        const SizedBox(width: 8),
                        ...[ Colors.black, const Color(0xFF1a1a2e), Colors.blue, Colors.red ]
                            .map((c) => GestureDetector(
                                  onTap: () => setState(() => _strokeColor = c),
                                  child: Container(
                                    width: 24, height: 24,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _strokeColor == c
                                            ? AppTheme.primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                )),
                        const SizedBox(width: 12),
                        const Text('Grosor:',
                            style: TextStyle(color: AppTheme.hint, fontSize: 12)),
                        const SizedBox(width: 8),
                        ...[1.5, 2.5, 4.0].map((w) => GestureDetector(
                              onTap: () => setState(() => _strokeWidth = w),
                              child: Container(
                                width: w == 1.5 ? 20 : w == 2.5 ? 26 : 32,
                                height: w == 1.5 ? 20 : w == 2.5 ? 26 : 32,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: _strokeWidth == w
                                      ? AppTheme.primary.withOpacity(0.15)
                                      : AppTheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _strokeWidth == w
                                        ? AppTheme.primary
                                        : AppTheme.border,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: w, height: w,
                                    decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            )),
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearCanvas,
                          child: const Row(children: [
                            Icon(Icons.refresh_rounded,
                                color: AppTheme.hint, size: 16),
                            SizedBox(width: 4),
                            Text('Limpiar',
                                style: TextStyle(
                                    color: AppTheme.hint, fontSize: 12)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Canvas
                    Expanded(
                      child: RepaintBoundary(
                        key: _canvasKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border, width: 1.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                painter: _SignaturePainter(
                                    _strokes, _strokeColor, _strokeWidth),
                                child: _strokes.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.draw_rounded,
                                                color: Colors.grey[300],
                                                size: 36),
                                            const SizedBox(height: 8),
                                            Text('Dibuja aquí tu firma',
                                                style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 14)),
                                          ],
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveFromCanvas,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_isSaving ? 'Guardando...' : 'Guardar firma',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),

                // ── TAB 2: Subir imagen ──
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.border,
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.upload_file_rounded,
                                color: AppTheme.primary, size: 30),
                          ),
                          const SizedBox(height: 16),
                          const Text('Sube tu firma como imagen',
                              style: TextStyle(
                                  color: AppTheme.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 8),
                          const Text(
                              'Formatos aceptados: PNG, JPG\nFondo transparente recomendado (PNG)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.hint, fontSize: 13, height: 1.5)),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _pickAndUploadImage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.image_rounded, size: 18),
                              label: Text(
                                  _isSaving
                                      ? 'Subiendo...'
                                      : 'Seleccionar imagen',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La imagen será usada como tu firma digital en los documentos firmados con BlockSign.',
                              style: TextStyle(
                                  color: AppTheme.hint,
                                  fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// SIGNATURE PAINTER
// ─────────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final Color color;
  final double strokeWidth;

  _SignaturePainter(this.strokes, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != null && stroke[i + 1] != null) {
          canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ─────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.hint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}