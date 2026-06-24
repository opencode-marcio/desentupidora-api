import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AnnotationStroke {
  final Color color;
  final double strokeWidth;
  final List<Offset> points;

  AnnotationStroke({
    required this.color,
    required this.strokeWidth,
    required this.points,
  });

  Map<String, dynamic> toJson(double imgW, double imgH) {
    return {
      'type': 'freehand',
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'strokeWidth': strokeWidth,
      'points': points.map((p) => [p.dx / imgW, p.dy / imgH]).toList(),
    };
  }
}

class PhotoAnnotationScreen extends StatefulWidget {
  final String imagePath;
  final String photoType;

  const PhotoAnnotationScreen({
    super.key,
    required this.imagePath,
    required this.photoType,
  });

  @override
  State<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends State<PhotoAnnotationScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<AnnotationStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  Color _currentColor = Colors.red;
  final double _strokeWidth = 4.0;
  ui.Image? _image;
  Size _imageSize = Size.zero;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    _imageSize = Size(img.width.toDouble(), img.height.toDouble());
    setState(() => _image = img);
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
    }
  }

  Offset _toImageCoords(Offset local) {
    if (_canvasSize.width == 0 || _canvasSize.height == 0) return local;
    final scale = _canvasSize.width / _imageSize.width;
    final imgH = _imageSize.height * scale;
    final top = (_canvasSize.height - imgH) / 2;
    return Offset(
      (local.dx) / scale.clamp(0.01, double.infinity),
      (local.dy - top) / scale.clamp(0.01, double.infinity),
    );
  }

  Future<void> _confirm() async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final pngBytes = byteData.buffer.asUint8List();

    final tempDir = Directory.systemTemp;
    final outputFile = File(
      '${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await outputFile.writeAsBytes(pngBytes);

    final annJson = jsonEncode(
      _strokes.map((s) => s.toJson(_imageSize.width, _imageSize.height)).toList(),
    );

    if (mounted) {
      Navigator.pop(context, {
        'imagePath': outputFile.path,
        'annotations': annJson,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Anotar - ${widget.photoType == 'before' ? 'ANTES' : widget.photoType == 'after' ? 'DEPOIS' : 'DURANTE'}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty ? null : _undo,
            tooltip: 'Desfazer',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
            tooltip: 'Limpar tudo',
          ),
          // Confirm button moved to bottom bar
        ],
      ),
      body: _image == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (d) {
                    setState(() => _currentPoints = [_toImageCoords(d.localPosition)]);
                  },
                  onPanUpdate: (d) {
                    setState(() => _currentPoints.add(_toImageCoords(d.localPosition)));
                  },
                  onPanEnd: (_) {
                    if (_currentPoints.length > 1) {
                      setState(() {
                        _strokes.add(AnnotationStroke(
                          color: _currentColor,
                          strokeWidth: _strokeWidth,
                          points: List.from(_currentPoints),
                        ));
                        _currentPoints = [];
                      });
                    } else {
                      _currentPoints = [];
                    }
                  },
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: CustomPaint(
                      size: _canvasSize,
                      painter: _AnnotationPainter(
                        image: _image!,
                        imageSize: _imageSize,
                        strokes: _strokes,
                        currentPoints: _currentPoints,
                        currentColor: _currentColor,
                        strokeWidth: _strokeWidth,
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _colorDot(Colors.red),
                const SizedBox(width: 12),
                _colorDot(Colors.blue),
                const SizedBox(width: 12),
                _colorDot(Colors.green),
                const SizedBox(width: 12),
                _colorDot(Colors.yellow),
                const SizedBox(width: 12),
                _colorDot(Colors.white),
                const SizedBox(width: 12),
                _colorDot(Colors.black),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 24),
                onPressed: _confirm,
                label: const Text('PRONTO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = _currentColor == color;
    return GestureDetector(
      onTap: () => setState(() => _currentColor = color),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.grey[700]!,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final ui.Image image;
  final Size imageSize;
  final List<AnnotationStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double strokeWidth;

  _AnnotationPainter({
    required this.image,
    required this.imageSize,
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / imageSize.width;
    final imgH = imageSize.height * scale;
    final top = (size.height - imgH) / 2;
    final rect = Rect.fromLTWH(0, top, size.width, imgH);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
      rect,
      Paint(),
    );

    canvas.save();
    canvas.translate(0, top);
    canvas.scale(scale);

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth);
    }
    if (currentPoints.length > 1) {
      _drawStroke(canvas, currentPoints, currentColor, strokeWidth);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
