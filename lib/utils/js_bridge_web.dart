// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Lee una variable global de `window`.
dynamic jsGet(String name) => js.context[name];

/// Asigna una variable global de `window`.
void jsSet(String name, dynamic value) => js.context[name] = value;

/// Llama una función global de `window`.
dynamic jsCall(String method, [List<dynamic>? args]) => js.context.callMethod(method, args);
