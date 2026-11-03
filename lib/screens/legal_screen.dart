import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Correo al que las personas pueden escribir para ejercer sus derechos.
/// Cámbialo aquí si usas otro buzón.
const kContactoLegal = 'juancho260406@gmail.com';

/// Fecha de la última actualización de los textos legales.
const kLegalActualizado = '3 de noviembre de 2026';

typedef _Sec = (String, List<String>);

const List<_Sec> _terminos = [
  ('1. Qué es DocBlockSign', [
    'DocBlockSign es un sistema para firmar y verificar documentos con apoyo de blockchain. Nació como proyecto de grado de Ingeniería de Software de la Universidad Manuela Beltrán (UMB) y se ofrece en fase de pruebas, sin costo.',
    'Al crear una cuenta o usar el servicio aceptas estos términos. Si no estás de acuerdo, no lo uses.',
  ]),
  ('2. Tu cuenta', [
    'Debes ser mayor de edad y dar datos verdaderos (nombre, correo, cédula y teléfono).',
    'Eres responsable de guardar tu contraseña y de lo que se haga con tu cuenta. Si sospechas que alguien más entró, cambia la contraseña y avísanos.',
  ]),
  ('3. Uso permitido', [
    'Puedes cargar documentos PDF y Word de hasta 10 MB para firmarlos, enviarlos a otras personas o verificarlos.',
    'No está permitido subir contenido ilegal, que viole derechos de otras personas o que contenga virus o código dañino, ni intentar acceder a cuentas o datos ajenos, ni sobrecargar el servicio.',
  ]),
  ('4. Alcance de la firma', [
    'La firma de DocBlockSign es una firma electrónica respaldada por blockchain, en el sentido de la Ley 527 de 1999. No es una firma digital emitida por una entidad de certificación digital acreditada.',
    'Su valor frente a terceros depende de la ley y de lo que acuerden las partes. Si un trámite exige firma digital certificada u otra formalidad, consulta antes de usar DocBlockSign.',
    'Las llaves de firma se generan para tu cuenta y las custodia el servidor, cifradas. Al firmar, autorizas su uso en tu nombre.',
  ]),
  ('5. Blockchain y registros permanentes', [
    'Para poder verificar un documento se registra en la cadena de bloques su huella criptográfica y los datos de la firma, no el documento. Un registro en blockchain no se puede borrar ni modificar.',
    'Si revocas una firma, la revocación se registra como un nuevo movimiento; el registro anterior sigue existiendo en la cadena.',
  ]),
  ('6. Tus documentos', [
    'Los documentos son tuyos. Nos das permiso solo para almacenarlos, procesarlos y mostrarlos a las personas que tú elijas, con el fin de prestar el servicio.',
    'Eres responsable de tener derecho a firmar y compartir lo que subes.',
  ]),
  ('7. Disponibilidad y responsabilidad', [
    'El servicio se ofrece «tal como está», en fase de pruebas. Puede tener interrupciones, errores o cambios, y no garantizamos que esté siempre disponible.',
    'En la medida que la ley lo permita, los responsables del proyecto no responden por daños indirectos, pérdida de datos o decisiones tomadas con base en el servicio. Guarda siempre copia de tus documentos originales.',
  ]),
  ('8. Suspensión y cierre', [
    'Podemos suspender cuentas que incumplan estos términos. Tú puedes eliminar tu cuenta desde Perfil, sección «Eliminar cuenta».',
  ]),
  ('9. Cambios', [
    'Podemos actualizar estos términos. Si el cambio es importante, te lo avisaremos en la aplicación o por correo. Seguir usando el servicio después del aviso significa que lo aceptas.',
  ]),
  ('10. Ley aplicable y contacto', [
    'Estos términos se rigen por las leyes de Colombia. Para dudas o reclamos escribe a $kContactoLegal.',
  ]),
];

const List<_Sec> _privacidad = [
  ('1. Quién es el responsable', [
    'Los responsables del tratamiento de tus datos son Juan Diego Pinzón Fontecha y Carlos Felipe Avilan Payares, estudiantes de Ingeniería de Software de la Universidad Manuela Beltrán, autores del proyecto DocBlockSign. Contacto: $kContactoLegal.',
    'Esta política sigue la Ley 1581 de 2012 de protección de datos personales (habeas data) y sus decretos reglamentarios.',
  ]),
  ('2. Qué datos recogemos', [
    'Al registrarte: nombre, correo, número de cédula, teléfono y contraseña (se guarda solo cifrada, nunca en texto).',
    'Al usar el servicio: los documentos que subes, las firmas, las personas a quienes los envías, los correos de notificación, la actividad de tu cuenta (auditoría) y los datos técnicos básicos de la sesión.',
    'Si activas «Entrar con huella», la huella o el rostro los lee tu teléfono. DocBlockSign no los recibe ni los guarda; solo recibe la respuesta «coincide» o «no coincide».',
  ]),
  ('3. Para qué los usamos', [
    'Crear y proteger tu cuenta, verificar tu correo, permitirte firmar, enviar y verificar documentos, avisarte de lo que pasa con ellos (por ejemplo recordatorios de firmas pendientes) y mantener un historial de auditoría.',
    'También para la seguridad del servicio y, de forma anónima o agregada, para evaluar el proyecto académico. No vendemos tus datos ni los usamos para publicidad.',
  ]),
  ('4. Autorización', [
    'Al marcar la casilla del registro nos autorizas de manera previa, expresa e informada para tratar tus datos con estas finalidades. Puedes revocar la autorización cuando quieras; si lo haces, no podremos seguir prestándote el servicio.',
  ]),
  ('5. Con quién compartimos datos', [
    'Con las personas que tú elijas: quien recibe un documento para firmar ve el documento y tu nombre y correo.',
    'Con proveedores que hacen posible el servicio: alojamiento y base de datos, envío de correos y verificación anti-robots de Google (reCAPTCHA y Gmail). Ellos pueden tratar datos fuera de Colombia.',
    'En la blockchain pública se registran solo huellas criptográficas y datos de la firma; esos registros son permanentes y visibles para cualquiera.',
    'Podemos entregar datos si una autoridad competente lo exige conforme a la ley.',
  ]),
  ('6. Cómo los protegemos', [
    'Contraseñas cifradas, comunicaciones por HTTPS, llaves de firma cifradas con AES-256-GCM y sesiones que vencen a los 7 días. Ningún sistema es infalible; si ocurre un incidente que te afecte, te lo informaremos.',
  ]),
  ('7. Cuánto tiempo los guardamos', [
    'Mientras tu cuenta esté activa y el tiempo necesario para cumplir obligaciones legales o resolver reclamos. Al eliminar tu cuenta borramos tus datos personales y documentos de nuestros sistemas, salvo lo que la ley nos obligue a conservar. Lo registrado en blockchain no se puede borrar (ver términos, punto 5).',
  ]),
  ('8. Tus derechos', [
    'Puedes conocer, actualizar y rectificar tus datos, pedir prueba de la autorización, saber cómo los usamos, presentar quejas ante la Superintendencia de Industria y Comercio, revocar la autorización y pedir la supresión de tus datos.',
    'Escribe a $kContactoLegal. Respondemos las consultas en máximo 10 días hábiles y los reclamos en máximo 15 días hábiles.',
  ]),
  ('9. Menores de edad', [
    'El servicio es para personas mayores de edad. No tratamos a sabiendas datos de menores.',
  ]),
  ('10. Cambios', [
    'Si cambiamos esta política te lo avisaremos en la aplicación o por correo. La fecha de la última actualización aparece arriba.',
  ]),
];

const List<_Sec> _cookies = [
  ('1. Qué usamos', [
    'DocBlockSign no usa cookies de publicidad ni de seguimiento de terceros. En la versión web usamos lo mínimo para que el servicio funcione.',
  ]),
  ('2. Almacenamiento necesario', [
    'Guardamos en tu navegador tu sesión (para que no tengas que iniciar sesión en cada visita) y tus preferencias de apariencia y accesibilidad (tema, contraste, tamaño).',
    'Sin esto el servicio no puede funcionar, por eso no requiere un aviso de aceptación aparte. Se borra al cerrar sesión o al limpiar los datos del sitio.',
  ]),
  ('3. Google reCAPTCHA', [
    'En el registro usamos reCAPTCHA de Google para evitar robots. Google puede poner cookies y leer datos de tu dispositivo para esta verificación, según su propia política de privacidad.',
  ]),
  ('4. Aplicación móvil', [
    'La aplicación Android no usa cookies. Guarda tu sesión y preferencias en el almacenamiento seguro del teléfono.',
  ]),
  ('5. Cómo controlarlas', [
    'Puedes borrar o bloquear cookies y datos del sitio desde la configuración de tu navegador. Si bloqueas lo necesario, el inicio de sesión y el registro pueden dejar de funcionar.',
  ]),
  ('6. Contacto', [
    'Dudas sobre este aviso: $kContactoLegal.',
  ]),
];

/// Términos y condiciones, política de privacidad y aviso de cookies.
/// [initialTab]: 0 términos, 1 privacidad, 2 cookies.
class LegalScreen extends StatelessWidget {
  final int initialTab;
  const LegalScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.text,
          elevation: 0,
          title: Text('Información legal',
              style: TextStyle(color: AppTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          bottom: TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.hint,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Términos'),
              Tab(text: 'Privacidad'),
              Tab(text: 'Cookies'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _Doc(title: 'Términos y condiciones', secciones: _terminos),
          _Doc(title: 'Política de privacidad', secciones: _privacidad),
          _Doc(title: 'Aviso de cookies', secciones: _cookies),
        ]),
      ),
    );
  }
}

class _Doc extends StatelessWidget {
  final String title;
  final List<_Sec> secciones;
  const _Doc({required this.title, required this.secciones});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(title, style: TextStyle(color: AppTheme.text, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Última actualización: $kLegalActualizado',
                style: TextStyle(color: AppTheme.hint, fontSize: 12)),
            const SizedBox(height: 20),
            for (final s in secciones) ...[
              Text(s.$1, style: TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final p in s.$2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(p, style: TextStyle(color: AppTheme.text, fontSize: 13.5, height: 1.55)),
                ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
