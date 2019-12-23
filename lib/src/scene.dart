import 'dart:ui';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'object.dart';
import 'camera.dart';
import 'mesh.dart';

typedef ObjectCreatedCallback = void Function(Object object);

class Scene {
  Scene({VoidCallback onUpdate, ObjectCreatedCallback onObjectCreated}) {
    this._onUpdate = onUpdate;
    this._onObjectCreated = onObjectCreated;
    camera = Camera();
    world = Object(scene: this);
    blendMode = BlendMode.srcOver;
  }
  Camera camera;
  Object world;
  Image texture;
  BlendMode blendMode;
  VoidCallback _onUpdate;
  ObjectCreatedCallback _onObjectCreated;
  int vertexCount;
  int faceCount;

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
    renderMesh.image = texture;
    return renderMesh;
  }

  void _renderObject(RenderMesh renderMesh, Object o, Matrix4 transform) {
    transform *= o.transform;

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
      // apply perspective to screen transform
      applyViewportTransform(v, viewportWidth, viewportHeight);
      final int xIndex = (vertexOffset + i) * 2;
      final int yIndex = xIndex + 1;
      final Float64List storage4 = v.storage;
      positions[xIndex] = storage4[0]; //v.x;
      positions[yIndex] = storage4[1]; //v.y;
      positionsZ[vertexOffset + i] = storage4[2]; //v.z;
    }
    renderMesh.vertexCount += vertexCount;

    // add faces to renderMesh
    final List<Polygon> renderIndices = renderMesh.indices;
    final List<Polygon> indices = o.mesh.indices;
    final int indexOffset = renderMesh.indexCount;
    final int indexCount = indices.length;
    for (int i = 0; i < indexCount; i++) {
      final Polygon p = indices[i];
      final vertex0 = vertexOffset + p.vertex0;
      final vertex1 = vertexOffset + p.vertex1;
      final vertex2 = vertexOffset + p.vertex2;
      final sumOfZ = positionsZ[vertex0] + positionsZ[vertex1] + positionsZ[vertex2];
      renderIndices[indexOffset + i] = Polygon(vertex0, vertex1, vertex2, sumOfZ);
    }
    renderMesh.indexCount += indexCount;

    // add vertex colors to renderMesh
    final Int32List renderColors = renderMesh.colors;
    final List<Color> colors = o.mesh.colors;
    final int colorCount = colors.length;
    for (int i = 0; i < colorCount; i++) {
      renderColors[vertexOffset + i] = colors[i].value;
    }

    // add texture coordinates to renderMesh
    final int imageWidth = o.mesh.textureRect.width.toInt();
    final int imageHeight = o.mesh.textureRect.height.toInt();
    final double imageLeft = o.mesh.textureRect.left;
    final double imageTop = o.mesh.textureRect.top;
    final Float32List renderTexcoords = renderMesh.texcoords;
    final List<Offset> texcoords = o.mesh.texcoords;
    final int texcoordCount = texcoords.length;
    for (int i = 0; i < texcoordCount; i++) {
      final Offset t = texcoords[i];
      final double x = t.dx * imageWidth + imageLeft;
      final double y = (1.0 - t.dy) * imageHeight + imageTop;
      final int xIndex = (vertexOffset + i) * 2;
      final int yIndex = xIndex + 1;
      renderTexcoords[xIndex] = x;
      renderTexcoords[yIndex] = y;
    }

    // render children
    List<Object> children = o.children;
    for (int i = 0; i < children.length; i++) {
      _renderObject(renderMesh, children[i], transform);
    }
  }

  void render(Canvas canvas, Size size) {
    final renderMesh = _makeRenderMesh();
    _renderObject(renderMesh, world, camera.projectionMatrix * camera.lookAtMatrix);

    // sort the faces by z
    renderMesh.indices.sort((Polygon a, Polygon b) {
      // return b.sumOfZ.compareTo(a.sumOfZ);
      final double az = a.sumOfZ;
      final double bz = b.sumOfZ;
      if (bz > az) return 1;
      if (bz < az) return -1;
      return 0;
    });

    // convert Polygon list to Uint16List
    final List<Polygon> renderIndices = renderMesh.indices;
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
      textureCoordinates: renderMesh.image == null ? null : renderMesh.texcoords,
      colors: renderMesh.colors,
      indices: indices,
    );

    final paint = Paint();
    if (renderMesh.image != null) {
      Float64List matrix4 = new Matrix4.identity().storage;
      final shader = ImageShader(renderMesh.image, TileMode.mirror, TileMode.mirror, matrix4);
      paint.shader = shader;
    }
    paint.blendMode = blendMode;
    canvas.drawVertices(vertices, BlendMode.src, paint);
  }

  void objectCreated(Object object) {
    if (object.mesh.image != null) updateTexture();
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

  void updateTexture() async {
    final meshes = List<Mesh>();
    _getAllMesh(meshes, world);
    texture = await packingTexture(meshes);
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
  Image image;
  int vertexCount;
  int indexCount;
}

/// Transform from homonegenous coordinates to the normalized device coordinates，and then transform to viewport.
void applyViewportTransform(Vector4 v, double viewportWidth, double viewportHeight) {
  final storage = v.storage;
  //perspective division,
  final double w = storage[3];
  final double x = storage[0] / w;
  final double y = storage[1] / w;
  final double z = storage[2] / w;
  // Remaps coordinates from [-1, 1] to the [0, viewport] space.
  storage[0] = (1.0 + x) * viewportWidth / 2;
  storage[1] = (1.0 - y) * viewportHeight / 2;
  storage[2] = z;
}
