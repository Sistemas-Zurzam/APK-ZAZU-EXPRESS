import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String result = 'Aún no se escaneó ningún QR';
  bool handled = false;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Stack(children: [
    MobileScanner(controller: controller, onDetect: (capture) {
      if (handled || capture.barcodes.isEmpty) return;
      final value = capture.barcodes.first.rawValue;
      if (value == null) return;
      handled = true;
      setState(() => result = value);
      controller.stop();
    }),
    Positioned.fill(child: IgnorePointer(child: Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)))))),
    Positioned(left: 20, right: 20, bottom: 28, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(result, textAlign: TextAlign.center), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: controller.toggleTorch, icon: const Icon(Icons.flashlight_on)), IconButton(onPressed: () { handled = false; setState(() => result = 'Aún no se escaneó ningún QR'); controller.start(); }, icon: const Icon(Icons.refresh))])])))),
  ]);
}
