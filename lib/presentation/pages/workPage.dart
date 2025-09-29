import 'package:flutter/material.dart';

class WorkPage extends StatelessWidget {
  const WorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajo'),
      ),
      body: const Center(
        child: Text('Aquí irá el registro de actividades de trabajo'),
      ),
    );
  }
}
