import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inicio")),
      body: const Center(
        child: Text("Bienvenido a BlockSign 🚀"),
      ),
    );
  }
}