import 'package:flutter/material.dart';

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Series / Anime / Manga'),
      ),
      body: const Center(
        child: Text('Aquí irá el registro de series, anime y manga'),
      ),
    );
  }
}
