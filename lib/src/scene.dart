import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:vector_math/vector_math_64.dart';
import 'object.dart';
import 'camera.dart';
import 'mesh.dart';
import 'material.dart';
import 'light.dart';

typedef ObjectCreatedCallback = void Function(Object object);

class Scene {
  Scene({VoidCallback onUpdate, ObjectCreatedCallback onObjectCreated}) {
    this._onUpdate = onUpdate;
    this._onObjectCreated = onObjectCreated;
    light = Light();
    camera = Camera();
    world = Object(scene: this);
    blendMode = BlendMode.srcOver;
    textureBlendMode = BlendMode.srcOver;
  }

  Light light;
  Camera camera;
  Object world;
  Image texture;
  BlendMode blendMode;
  BlendMode textureBlendMode;
  VoidCallback _onUpdate;
  ObjectCreatedCallback _onObjectCreated;
  int vertexCount;
  int faceCount;
  bool _needsUpdateTexture = false;

  // calculate the total number of vertices and faces
  void _calculateVertices(Object o) {
    vertexCount += o.mesh.vertices.length;
    faceCount += o.mesh.indices.length;
    final List<Object> children = o.children;
    for (int i = 0; i < children.length; i++) {
      _calculateVertices(children[i]);
    }
  }

  RenderMesh _makeRenderMesh() {
    vertexCount = 0;
    faceCount = 0;
    _calculateVertices(world);
    final renderMesh = RenderMesh(vertexCount, faceCount);
    renderMesh.texture = texture;
    return renderMesh;
  }

  bool _isBackFace(double ax, double ay, double bx, double by, double cx, double cy) {
    double area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay);
    return area <= 0;
  }

  bool _isClippedFace(double ax, double ay, double az, double bx, double by, double bz, double cx, double cy, double cz) {
    // clip if at least one vertex is outside the near and far plane
    if (az < 0 || az > 1 || bz < 0 || bz > 1 || cz < 0 || cz > 1) return true;
    // clip if the face's bounding box does not intersect the viewport
    double left;
    double right;
    if (ax < bx) {
      left = ax;
      right = bx;
    } else {
      left = bx;
      right = ax;
    }
    if (left > cx) left = cx;
    if (left > 1) return true;
    if (right < cx) right = cx;
    if (right < -1) return true;

    double top;
    double bottom;
    if (ay < by) {
      top = ay;
      bottom = by;
    } else {
      top = by;
      bottom = ay;
    }
    if (top > cy) top = cy;
    if (top > 1) return true;
    if (bottom < cy) bottom = cy;
    if (bottom < -1) return true;
    return false;
  }

  void _renderObject(RenderMesh renderMesh, Object o, Matrix4 model, Matrix4 view, Matrix4 projection) {
    if (!o.visiable) return;
    model *= o.transform;
    final Matrix4 transform = projection * view * model;

    // apply transform and add vertices to renderMesh
    final double viewportWidth = camera.viewportWidth;
    final double viewportHeight = camera.viewportHeight;
    final Float32List positions = renderMesh.positions;
    final Float32List positionsZ = renderMesh.positionsZ;
    final List<Vector3> vertices = o.mesh.vertices;
    final int vertexOffset = renderMesh.vertexCount;
    final int vertexCount = vertices.length;
    final Vector4 v = Vector4.identity();
    for (int i = 0; i < vertexCount; i++) {
      // Conver Vector3 to Vector4
      final Float64List storage3 = vertices[i].storage;
      v.setValues(storage3[0], storage3[1], storage3[2], 1.0);
      // apply "model => world => camera => perspective" transform
      v.applyMatrix4(transform);
      // transform from homonegenous coordinates to the normalized device coordinates，
      final int xIndex = (vertexOffset + i) * 2;
      final int yIndex = xIndex + 1;
      final Float64List storage4 = v.storage;
      final double w = storage4[3]; //v.w;
      positions[xIndex] = storage4[0] / w; //v.x;
      positions[yIndex] = storage4[1] / w; //v.y;
      positionsZ[vertexOffset + i] = storage4[2] / w; //v.z;
    }
    renderMesh.vertexCount += vertexCount;

    // add faces to renderMesh
    final List<Polygon> renderIndices = renderMesh.indices;
    final List<Polygon> indices = o.mesh.indices;
    final int indexOffset = renderMesh.indexCount;
    final int indexCount = indices.length;
    final bool culling = o.backfaceCulling;
    for (int i = 0; i < indexCount; i++) {
      final Polygon p = indices[i];
      final int vertex0 = vertexOffset + p.vertex0;
      final int vertex1 = vertexOffset + p.vertex1;
      final int vertex2 = vertexOffset + p.vertex2;
      final double ax = positions[vertex0 * 2];
      final double ay = positions[vertex0 * 2 + 1];
      final double az = positionsZ[vertex0];
      final double bx = positions[vertex1 * 2];
      final double by = positions[vertex1 * 2 + 1];
      final double bz = positionsZ[vertex1];
      final double cx = positions[vertex2 * 2];
      final double cy = positions[vertex2 * 2 + 1];
      final double cz = positionsZ[vertex2];
      if (!culling || !_isBackFace(ax, ay, bx, by, cx, cy)) {
        if (!_isClippedFace(ax, ay, az, bx, by, bz, cx, cy, cz)) {
          final double sumOfZ = az + bz + cz;
          renderIndices[indexOffset + i] = Polygon(vertex0, vertex1, vertex2, sumOfZ);
        }
      }
    }
    renderMesh.indexCount += indexCount;

    if (o.lighting) {
      final Int32List renderColors = renderMesh.colors;
      final Matrix4 vertexTransform = model;
      final Matrix4 normalTransform = (model.clone()..invert()).transposed();
      final Vector3 viewPosition = camera.position;
      final Material material = o.mesh.material;
      final Vector3 a = Vector3.zero();
      final Vector3 b = Vector3.zero();
      final Vector3 c = Vector3.zero();

      for (int i = 0; i < indexCount; i++) {
        // check if the face is clipped
        if (renderIndices[indexOffset + i] != null) {
          final Polygon p = indices[i];
          a.setFrom(vertices[p.vertex0]);
          b.setFrom(vertices[p.vertex1]);
          c.setFrom(vertices[p.vertex2]);
          final Vector3 normal = normalVector(a, b, c)
            ..applyMatrix4(normalTransform)
            ..normalize();
          a.applyMatrix4(vertexTransform);
          b.applyMatrix4(vertexTransform);
          c.applyMatrix4(vertexTransform);

          renderColors[vertexOffset + p.vertex0] = light.shading(viewPosition, a, normal, material).value;
          renderColors[vertexOffset + p.vertex1] = light.shading(viewPosition, b, normal, material).value;
          renderColors[vertexOffset + p.vertex2] = light.shading(viewPosition, c, normal, material).value;
        }
      }
    } else {
      // add vertex colors to renderMesh
      final Int32List renderColors = renderMesh.colors;
      final List<Color> colors = o.mesh.colors;
      final int colorCount = o.mesh.vertices.length;
      if (colorCount != o.mesh.colors.length) {
        final int colorValue = (o.mesh.texture != null) ? Color.fromARGB(0, 0, 0, 0).value : toColor(o.mesh.material.diffuse, o.mesh.material.opacity).value;
        for (int i = 0; i < colorCount; i++) {
          renderColors[vertexOffset + i] = colorValue;
        }
      } else {
        for (int i = 0; i < colorCount; i++) {
          renderColors[vertexOffset + i] = colors[i].value;
        }
      }
    }

    // apply perspective to screen transform
    for (int i = 0; i < vertexCount; i++) {
      final int x = (vertexOffset + i) * 2;
      final int y = x + 1;
      // remaps coordinates from [-1, 1] to the [0, viewport] space.
      positions[x] = (1.0 + positions[x]) * viewportWidth / 2;
      positions[y] = (1.0 - positions[y]) * viewportHeight / 2;
    }

    // add texture coordinates to renderMesh
    final int texcoordCount = o.mesh.vertices.length;
    final Float32List renderTexcoords = renderMesh.texcoords;
    if (o.mesh.texture != null && o.mesh.texcoords.length == texcoordCount) {
      final int imageWidth = o.mesh.textureRect.width.toInt();
      final int imageHeight = o.mesh.textureRect.height.toInt();
      final double imageLeft = o.mesh.textureRect.left;
      final double imageTop = o.mesh.textureRect.top;
      final List<Offset> texcoords = o.mesh.texcoords;
      for (int i = 0; i < texcoordCount; i++) {
        final Offset t = texcoords[i];
        final double x = t.dx * imageWidth + imageLeft;
        final double y = (1.0 - t.dy) * imageHeight + imageTop;
        final int xIndex = (vertexOffset + i) * 2;
        final int yIndex = xIndex + 1;
        renderTexcoords[xIndex] = x;
        renderTexcoords[yIndex] = y;
      }
    } else {
      for (int i = 0; i < texcoordCount; i++) {
        final int xIndex = (vertexOffset + i) * 2;
        final int yIndex = xIndex + 1;
        renderTexcoords[xIndex] = 0;
        renderTexcoords[yIndex] = 0;
      }
    }

    // render children
    List<Object> children = o.children;
    for (int i = 0; i < children.length; i++) {
      _renderObject(renderMesh, children[i], model, view, projection);
    }
  }

  void render(Canvas canvas, Size size) {
    // check if texture needs to update
    if (_needsUpdateTexture) {
      _needsUpdateTexture = false;
      _updateTexture();
    }

    // create render mesh from objects
    final renderMesh = _makeRenderMesh();
    _renderObject(renderMesh, world, Matrix4.identity(), camera.lookAtMatrix, camera.projectionMatrix);

    // remove the culled faces and recreate list.
    final List<Polygon> renderIndices = List<Polygon>();
    final List<Polygon> rawIndices = renderMesh.indices;
    renderIndices.length = rawIndices.length;
    int renderCount = 0;
    for (int i = 0; i < rawIndices.length; i++) {
      final Polygon p = rawIndices[i];
      if (p != null) renderIndices[renderCount++] = p;
    }
    renderIndices.length = renderCount;
    if (renderCount == 0) return;

    // sort the faces by z
    renderIndices.sort((Polygon a, Polygon b) {
      // return b.sumOfZ.compareTo(a.sumOfZ);
      final double az = a.sumOfZ;
      final double bz = b.sumOfZ;
      if (bz > az) return 1;
      if (bz < az) return -1;
      return 0;
    });

    // convert Polygon list to Uint16List
    final int indexCount = renderIndices.length;
    final Uint16List indices = Uint16List(indexCount * 3);
    for (int i = 0; i < indexCount; i++) {
      final int index0 = i * 3;
      final int index1 = index0 + 1;
      final int index2 = index0 + 2;
      final Polygon polygon = renderIndices[i];
      indices[index0] = polygon.vertex0;
      indices[index1] = polygon.vertex1;
      indices[index2] = polygon.vertex2;
    }

    final vertices = Vertices.raw(
      VertexMode.triangles,
      renderMesh.positions,
      textureCoordinates: renderMesh.texture == null ? null : renderMesh.texcoords,
      colors: renderMesh.colors,
      indices: indices,
    );

    final paint = Paint();
    if (renderMesh.texture != null) {
      Float64List matrix4 = new Matrix4.identity().storage;
      final shader = ImageShader(renderMesh.texture, TileMode.mirror, TileMode.mirror, matrix4);
      paint.shader = shader;
    }
    paint.blendMode = blendMode;
    canvas.drawVertices(vertices, textureBlendMode, paint);
  }

  void objectCreated(Object object) {
    updateTexture();
    if (_onObjectCreated != null) _onObjectCreated(object);
  }

  void update() {
    if (_onUpdate != null) _onUpdate();
  }

  void _getAllMesh(List<Mesh> meshes, Object object) {
    meshes.add(object.mesh);
    final List<Object> children = object.children;
    for (int i = 0; i < children.length; i++) {
      _getAllMesh(meshes, children[i]);
    }
  }

  void _updateTexture() async {
    final meshes = List<Mesh>();
    _getAllMesh(meshes, world);
    texture = await packingTexture(meshes);
    update();
  }

  /// Mark needs update texture
  void updateTexture() {
    _needsUpdateTexture = true;
    update();
  }
}

class RenderMesh {
  RenderMesh(int vertexCount, int faceCount) {
    positions = Float32List(vertexCount * 2);
    positionsZ = Float32List(vertexCount);
    texcoords = Float32List(vertexCount * 2);
    colors = Int32List(vertexCount);
    indices = List<Polygon>(faceCount);
    this.vertexCount = 0;
    this.indexCount = 0;
  }
  Float32List positions;
  Float32List positionsZ;
  Float32List texcoords;
  Int32List colors;
  List<Polygon> indices;
  Image texture;
  int vertexCount;
  int indexCount;
}
