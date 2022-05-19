import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

class CameraControls{
  CameraControls({
    this.zoom = true,
    this.panX = true,
    this.panY = true,
    this.orbitX = true,
    this.orbitY = true,
  });
  bool zoom;
  bool panX;
  bool panY;
  bool orbitX;
  bool orbitY;
}

class Camera {
  Camera({
    Vector3? position,
    Vector3? target,
    Vector3? up,
    this.fov = 60.0,
    this.near = 0.1,
    this.far = 10000,
    this.zoom = 1.0,
    this.viewportWidth = 100.0,
    this.viewportHeight = 100.0,
    CameraControls? cameraControls
  }) {
    if (position != null) position.copyInto(this.position);
    if (target != null) target.copyInto(this.target);
    if (up != null) up.copyInto(this.up);
    this.cameraControls = cameraControls != null?cameraControls:CameraControls();
    _zoomStart = zoom;
  }

  late CameraControls cameraControls;
  final Vector3 position = Vector3(0.0, 0.0, -10.0);
  final Vector3 target = Vector3(0.0, 0.0, 0.0);
  final Vector3 up = Vector3(0.0, 1.0, 0.0);
  final Vector3 pan = Vector3(0,0,0);
  final Vector3 angle = Vector3(0,0,0);
  
  double fov;
  double near;
  double far;
  double zoom;
  late double _zoomStart;
  double viewportWidth;
  double viewportHeight;

  double get aspectRatio => viewportWidth / viewportHeight;

  Matrix4 get lookAtMatrix {
    return makeViewMatrix(position, target, up)*Matrix4.translation(pan);
  }
  Matrix4 get projectionMatrix {
    if(zoom < near)
      zoom = near;
    final double top = near * math.tan(radians(fov) / 2.0) / ((!cameraControls.zoom)?_zoomStart:zoom);
    final double bottom = -top;
    final double right = top * aspectRatio;
    final double left = -right;
    return makeFrustumMatrix(left, right, bottom, top, near, far);
  }

  void panCamera(Vector2 from, Vector2 to, [double sensitivity = 1.0]){
    final double y = (!cameraControls.panX)?0:((to.x - from.x)) * sensitivity/ (viewportWidth * 0.5);
    final double x = (!cameraControls.panY)?0:((to.y - from.y)) * sensitivity/ (viewportHeight * 0.5);

    Vector2 delta = Vector2(x, y);
    Vector3 moveDirection = Vector3(delta.x, delta.y, 0);

    Vector3 _eye = position - target;
    Vector3 eyeDirection = _eye.normalized();
    Vector3 upDirection = up.normalized();
    Vector3 sidewaysDirection = upDirection.cross(eyeDirection).normalized();
    upDirection.scale(delta.y);
    sidewaysDirection.scale(delta.x);
    moveDirection = upDirection + sidewaysDirection;
    Vector3 axis = moveDirection.cross(_eye);

    pan.x += axis.x;
    pan.y += axis.y;
    pan.z += axis.z;
  }

  void trackBall(Vector2 from, Vector2 to, [double sensitivity = 1.0]) {
    final double x = (!cameraControls.orbitX)?0:-(to.x - from.x) * sensitivity / (viewportWidth * 0.5);
    final double y = (!cameraControls.orbitY)?0:(to.y - from.y) * sensitivity / (viewportHeight * 0.5);
    Vector2 delta = Vector2(x, y);
    Vector3 moveDirection = Vector3(delta.x, delta.y, 0);
    final double angle = moveDirection.length;
    if (angle > 0) {
      Vector3 _eye = position-target;
      Vector3 eyeDirection = _eye.normalized();
      Vector3 upDirection = up.normalized();
      Vector3 sidewaysDirection = upDirection.cross(eyeDirection).normalized();
      upDirection.scale(delta.y);
      sidewaysDirection.scale(delta.x);
      moveDirection = upDirection + sidewaysDirection;
      Vector3 axis = moveDirection.cross(_eye).normalized();
      Quaternion q = Quaternion.axisAngle(axis, angle);
      q.rotate(position);
      q.rotate(up);
    }
  }
}
