/// Nombre de un documento sin ".pdf" / ".docx" / ".doc" (el tipo ya se ve en el ícono)
String docDisplayName(String? title) {
  final t = (title ?? '').trim();
  if (t.isEmpty) return 'Documento';
  final m = RegExp(r'\.(pdf|docx|doc)$', caseSensitive: false).firstMatch(t);
  return (m != null && m.start > 0) ? t.substring(0, m.start) : t;
}
