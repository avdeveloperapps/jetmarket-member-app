import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class LoanSignaturePadScreen extends StatefulWidget {
  const LoanSignaturePadScreen({super.key});

  @override
  State<LoanSignaturePadScreen> createState() => _LoanSignaturePadScreenState();
}

class _LoanSignaturePadScreenState extends State<LoanSignaturePadScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<Offset?> _points = <Offset?>[];

  bool get _hasSignature => _points.any((point) => point != null);

  void _addPoint(Offset point) => setState(() => _points.add(point));

  void _endStroke() => setState(() => _points.add(null));

  void _clear() => setState(_points.clear);

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      while (_points.isNotEmpty && _points.last == null) {
        _points.removeLast();
      }
      while (_points.isNotEmpty && _points.last != null) {
        _points.removeLast();
      }
    });
  }

  Future<void> _save() async {
    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bubuhkan tanda tangan terlebih dahulu.')),
      );
      return;
    }
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null || !mounted) return;

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/loan-signature-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    if (mounted) Navigator.of(context).pop(file.path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Tanda Tangan'),
          actions: [
            IconButton(
              tooltip: 'Urungkan goresan terakhir',
              onPressed: _points.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Hapus tanda tangan',
              onPressed: _points.isEmpty ? null : _clear,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bubuhkan tanda tangan Anda',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD5D5D5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) =>
                            _addPoint(details.localPosition),
                        onPanUpdate: (details) =>
                            _addPoint(details.localPosition),
                        onPanEnd: (_) => _endStroke(),
                        onPanCancel: _endStroke,
                        child: CustomPaint(
                          painter: _LoanSignaturePainter(
                            List<Offset?>.of(_points),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _hasSignature ? _save : null,
                    child: const Text('Gunakan TTD'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LoanSignaturePainter extends CustomPainter {
  const _LoanSignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF161616)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    Offset? previous;
    for (final point in points) {
      if (point == null) {
        previous = null;
        continue;
      }
      if (previous == null) {
        canvas.drawCircle(point, paint.strokeWidth / 2, paint);
      } else {
        canvas.drawLine(previous, point, paint);
      }
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _LoanSignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
