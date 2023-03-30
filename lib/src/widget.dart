import 'dart:ui';
import 'package:flutter/widgets.dart' hide Image;
import 'package:vector_math/vector_math_64.dart';
import 'scene.dart';

typedef void SceneCreatedCallback(Scene scene);

class Cube extends StatefulWidget {
  Cube({
    Key? key,
    this.interactive = true,
    this.zoom = true,
    this.onSceneCreated,
    this.onObjectCreated,
  }) : super(key: key);

  final bool interactive;
  final bool zoom;
  final SceneCreatedCallback? onSceneCreated;
  final ObjectCreatedCallback? onObjectCreated;

  @override
  _CubeState createState() => _CubeState();
}

class _CubeState extends State<Cube> {
  late Scene scene;
  late Offset _lastFocalPoint;
  double? _lastZoom;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = null;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    scene.camera.trackBall(toVector2(_lastFocalPoint), toVector2(details.localFocalPoint), 1.5);
    _lastFocalPoint = details.localFocalPoint;
    if (widget.zoom) {
      if (_lastZoom == null) {
        _lastZoom = scene.camera.zoom;
      } else {
        scene.camera.zoom = _lastZoom! * details.scale;
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    scene = Scene(
      onUpdate: () => setState(() {}),
      onObjectCreated: widget.onObjectCreated,
    );
    // prevent setState() or markNeedsBuild called during build
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      widget.onSceneCreated?.call(scene);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      scene.camera.viewportWidth = constraints.maxWidth;
      scene.camera.viewportHeight = constraints.maxHeight;
      final customPaint = CustomPaint(
        painter: _CubePainter(scene),
        size: Size(constraints.maxWidth, constraints.maxHeight),
      );
      return widget.interactive
          ? GestureDetector(
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              child: customPaint,
            )
          : customPaint;
    });
  }
}

class _CubePainter extends CustomPainter {
  final Scene _scene;
  const _CubePainter(this._scene);

  @override
  void paint(Canvas canvas, Size size) {
    _scene.render(canvas, size);
  }

  // We should repaint whenever the board changes, such as board.selected.
  @override
  bool shouldRepaint(_CubePainter oldDelegate) {
    return true;
  }
}

/// Convert Offset to Vector2
Vector2 toVector2(Offset value) {
  return Vector2(value.dx, value.dy);
}
