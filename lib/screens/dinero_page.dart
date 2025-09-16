import 'package:flutter/material.dart';

class DineroPage extends StatelessWidget {
  const DineroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Dinero'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Regresar',
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Pantalla de Dinero',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
