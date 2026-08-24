class AppConfig {
  // Cambia esto a false cuando quieras usar producción local
  static const bool isLocal = bool.fromEnvironment('IS_LOCAL', defaultValue: false);
  
  static const String _prod = 'https://blocksign-backend.onrender.com';
  static const String _local = 'http://localhost:3000';
  
  static String get apiUrl => isLocal ? _local : _prod;
}