import 'package:flutter/material.dart';

/// STUB temporário — versão funcional será habilitada com impressora física.
class TelaImpressora extends StatelessWidget {
  const TelaImpressora({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impressora')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Impressão Bluetooth desabilitada no modo teste',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Será habilitada quando o app for instalado em tablet físico com impressora pareada.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
