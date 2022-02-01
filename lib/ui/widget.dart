import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_cube/scene/scene.dart';
import 'package:flutter/material.dart';

typedef void SceneCreatedCallback(Scene scene);
enum CubeCallbacks{OnTap,RemoveObject}

class Cube extends StatefulWidget {
  Cube({
    Key? key,
    this.interactive = true,
    this.onSceneCreated,
    this.onObjectCreated,
    this.onSceneUpdated,
    this.callback,
  }) : super(key: key);

  final bool interactive;
  final SceneCreatedCallback? onSceneCreated;
  final ObjectCreatedCallback? onObjectCreated;
  final VoidCallback? onSceneUpdated;
  final Function({CubeCallbacks call, Offset details})? callback;
  
  @override
  _CubeState createState() => _CubeState();
}

class _CubeState extends State<Cube> {
  late Scene scene;
  late Offset _lastFocalPoint;
  double? _lastZoom;
  double _scroll = 1.0;
  double _scale = 0;
  int _mouseType = 0;
  bool tapped = false;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _lastZoom = null;
  }
  void _handelPanUpdate(Offset localFocalPoint){
    scene.camera.panCamera(toVector2(_lastFocalPoint), toVector2(localFocalPoint), 1.5);
  }

  void _handleScaleUpdate(double scale, Offset localFocalPoint, bool pan) {
    if (_lastZoom == null){
      _scale = scale;
      _lastZoom = scene.camera.zoom;
    }
      scene.camera.zoom = _lastZoom !* scale;

    if(_mouseType == 1 || !pan)
      scene.camera.trackBall(toVector2(_lastFocalPoint), toVector2(localFocalPoint), 1.5);
    else if(_mouseType == 2 || pan)
      _handelPanUpdate(localFocalPoint);
    
    _lastFocalPoint = localFocalPoint;
    setState(() {});
  }
  @override
  void initState() {
    super.initState();
    scene = Scene(
      onUpdate: () => setState(() {
        widget.onSceneUpdated?.call();
        if(tapped){
          widget.callback?.call(call: CubeCallbacks.OnTap);
          tapped = false;
        }
      }),
      onObjectCreated: widget.onObjectCreated,
    );
    // prevent setState() or markNeedsBuild called during build
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      widget.onSceneCreated?.call(scene);
      _scroll = scene.camera.zoom;
    });
  }
  @override
  void dispose(){
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      scene.camera.viewportWidth = constraints.maxWidth;
      scene.camera.viewportHeight = constraints.maxHeight;
      final customPaint = CustomPaint(
        painter: _CubePainter(scene),
        size: Size(constraints.maxWidth, constraints.maxHeight),
        isComplex: true,
      );
      return widget.interactive
      ?Listener(
        onPointerMove: (details){
          _mouseType = details.buttons;
        },
        onPointerHover: (details){
          if(scene.rayCasting)
            scene.updateHoverLocation(details.localPosition);
        },
        onPointerSignal: (details){
          if(details is PointerScrollEvent){
            if (_lastZoom == null)
              _scroll = _scroll;
            else
              if(scene.camera.zoom > 0.5 || details.scrollDelta.dy > 0)
                _scroll = _scroll+details.scrollDelta.dy*0.01;
              
            _lastFocalPoint = details.localPosition;
            _handleScaleUpdate(_scroll,details.localPosition,false);//_lastFocalPoint
          }
        },
        child: GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: (details){
            bool pan = false;
            if(_scale < details.scale+0.1 && _scale > details.scale-0.1)
              pan = true;
            _handleScaleUpdate(details.scale,details.localFocalPoint, pan);
          },
          onTapDown: (TapDownDetails details){
            _lastZoom = null;
            scene.updateTapLocation(details.localPosition);
            tapped = true;
            setState(() {});
            //widget.callback?.call(call: CubeCallbacks.OnTap,details: details.localPosition);
          },
          onTapUp: (TapUpDetails details){
            setState(() {});
          },
          child: customPaint,
        )
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
