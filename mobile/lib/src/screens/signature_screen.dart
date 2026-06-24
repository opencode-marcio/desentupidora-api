import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  List<List<Offset>> _strokes = [];
  List<Offset> _currentPoints = [];

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentPoints.clear();
    });
  }

  Future<String?> _confirm() async {
    if (_strokes.isEmpty) return null;

    double minX = double.infinity, minY = double.infinity;
    double maxX = 0, maxY = 0;
    for (final stroke in _strokes) {
      for (final pt in stroke) {
        minX = min(minX, pt.dx);
        minY = min(minY, pt.dy);
        maxX = max(maxX, pt.dx);
        maxY = max(maxY, pt.dy);
      }
    }

    const pad = 15.0;
    double cropW = (maxX - minX + pad * 2);
    double cropH = (maxY - minY + pad * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (cropH > cropW) {
      canvas.translate(0, cropW);
      canvas.rotate(-pi / 2);
      canvas.translate(-minX + pad, -minY + pad);
    } else {
      canvas.translate(-minX + pad, -minY + pad);
    }

    if (cropH > cropW) {
      final tmp = cropW;
      cropW = cropH;
      cropH = tmp;
    }

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(cropW.ceil(), cropH.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final pngBytes = byteData.buffer.asUint8List();
    final base64Str = base64Encode(pngBytes);
    return 'data:image/png;base64,$base64Str';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinatura do Cliente'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _strokes.isEmpty ? null : _undo),
          IconButton(icon: const Icon(Icons.clear_all), onPressed: _strokes.isEmpty ? null : _clear),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: GestureDetector(
                        onPanStart: (d) {
                          setState(() => _currentPoints = [d.localPosition]);
                        },
                        onPanUpdate: (d) {
                          setState(() => _currentPoints.add(d.localPosition));
                        },
                        onPanEnd: (_) {
                          if (_currentPoints.length > 1) {
                            setState(() {
                              _strokes.add(List.from(_currentPoints));
                              _currentPoints = [];
                            });
                          } else {
                            _currentPoints = [];
                          }
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _SignaturePainter(
                            strokes: _strokes,
                            currentPoints: _currentPoints,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        width: 280,
                        height: 1,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: Text('Assine acima', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                onPressed: () async {
                  final result = await _confirm();
                  if (result != null) {
                    Navigator.pop(context, result);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Desenhe a assinatura primeiro')),
                    );
                  }
                },
                label: const Text('Confirmar Assinatura'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentPoints;

  _SignaturePainter({required this.strokes, required this.currentPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentPoints.length > 1) {
      _drawStroke(canvas, currentPoints, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
