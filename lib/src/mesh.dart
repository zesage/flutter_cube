import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'material.dart';

class Polygon {
  Polygon(this.vertex0, this.vertex1, this.vertex2, [this.sumOfZ = 0]);
  int vertex0;
  int vertex1;
  int vertex2;
  double sumOfZ;
  List<int> copyToArray() => [vertex0, vertex1, vertex2];
  void copyFromArray(List<int> array, [int offset = 0]) {
    final int i = offset;
    vertex0 = array[i];
    vertex1 = array[i + 1];
    vertex2 = array[i + 2];
  }
}

// wolcy97: 2020-01-31
int _getVertexIndex(String vIndex) {
  if (int.parse(vIndex) < 0)
    return int.parse(vIndex) + 1;
  else
    return int.parse(vIndex) - 1;
}

class Mesh {
  Mesh({List<Vector3>? vertices, List<Offset>? texcoords, List<Polygon>? indices, List<Color>? colors, this.texture, Rect? textureRect, this.texturePath, Material? material, this.name}) {
    this.vertices = vertices ?? <Vector3>[];
    this.texcoords = texcoords ?? <Offset>[];
    this.colors = colors ?? <Color>[];
    this.indices = indices ?? <Polygon>[];
    this.material = material ?? Material();
    this.textureRect = textureRect ?? Rect.fromLTWH(0, 0, texture?.width.toDouble() ?? 1.0, texture?.height.toDouble() ?? 1.0);
  }
  late List<Vector3> vertices;
  late List<Offset> texcoords;
  late List<Color> colors;
  late List<Polygon> indices;
  Image? texture;
  late Rect textureRect;
  String? texturePath;
  late Material material;
  String? name;
}

/// Loading mesh from Wavefront's object file (.obj).
/// Reference：http://paulbourke.net/dataformats/obj/
///
Future<List<Mesh>> loadObj(String fileName, bool normalized, {bool isAsset = true}) async {
  Map<String, Material>? materials;
  List<Vector3> vertices = <Vector3>[];
  List<Offset> texcoords = <Offset>[];
  List<Polygon> vertexIndices = <Polygon>[];
  List<Polygon> textureIndices = <Polygon>[];
  List<String> elementNames = <String>[];
  List<String> elementMaterials = <String>[];
  List<int> elementOffsets = <int>[];
  String? materialName;
  String? objectlName;
  String? groupName;
  String basePath = path.dirname(fileName);

  var data;
  if (isAsset) {
    // load obj data from asset.
    data = await rootBundle.loadString(fileName);
  } else {
    // load obj data from file.
    data = await File(fileName).readAsString();
  }
  final lines = data.split('\n');
  for (var line in lines) {
    List<String> parts = line.trim().split(RegExp(r"\s+"));

    switch (parts[0]) {
      case 'mtllib':
        // load material library file. eg: mtllib master.mtl
        final mtlFileName = path.join(basePath, parts[1]);
        materials = await loadMtl(mtlFileName, isAsset: isAsset);
        break;
      case 'usemtl':
        // material name from material library. eg: usemtl red
        if (parts.length >= 2) materialName = parts[1];
        // create a new mesh element
        final String elementName = objectlName ?? groupName ?? materialName ?? '';
        elementNames.add(elementName);
        elementMaterials.add(materialName ?? '');
        elementOffsets.add(vertexIndices.length);
        break;
      case 'g':
        // the name for the group. eg: g front cube
        if (parts.length >= 2) groupName = parts[1];
        break;
      case 'o':
        // the user-defined object name. eg: o cube
        if (parts.length >= 2) objectlName = parts[1];
        break;
      case 'v':
        // a geometric vertex and its x y z coordinates. eg: v 0.000000 2.000000 0.000000
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          vertices.add(v);
        }
        break;
      case 'vt':
        // eg: vt 0.000000 0.000000
        if (parts.length >= 3) {
          double x = double.parse(parts[1]);
          double y = double.parse(parts[2]);
          if (x < 0 || x > 1.0) x %= 1.0;
          if (y < 0 || y > 1.0) y %= 1.0;
          final vt = Offset(x, y);
          texcoords.add(vt);
        }
        break;
      case 'f':
        if (parts.length >= 4) {
          // eg: f 1/1 2/2 3/3
          final List<String> p1 = parts[1].split('/');
          final List<String> p2 = parts[2].split('/');
          final List<String> p3 = parts[3].split('/');
          Polygon vi = Polygon(_getVertexIndex(p1[0]), _getVertexIndex(p2[0]), _getVertexIndex(p3[0]));
          vertexIndices.add(vi);
          Polygon ti = Polygon(0, 0, 0);
          if ((p1.length >= 2 && p1[1] != '') && (p2.length >= 2 && p2[1] != '') && (p3.length >= 2 && p3[1] != '')) {
            ti = Polygon(_getVertexIndex(p1[1]), _getVertexIndex(p2[1]), _getVertexIndex(p3[1]));
            textureIndices.add(ti);
          }
          // polygon to triangle. eg: f 1/1 2/2 3/3 4/4 ==> f 1/1 2/2 3/3 + f 1/1 3/3 4/4
          for (int i = 4; i < parts.length; i++) {
            final List<String> p3 = parts[i].split('/');
            vi = Polygon(vi.vertex0, vi.vertex2, _getVertexIndex(p3[0]));
            vertexIndices.add(vi);
            if (p3.length >= 2 && p3[1] != '') {
              ti = Polygon(ti.vertex0, ti.vertex2, _getVertexIndex(p3[1]));
              textureIndices.add(ti);
            }
          }
        }
        break;
      default:
    }
  }
  final meshes = await _buildMesh(
    vertices,
    texcoords,
    vertexIndices,
    textureIndices,
    materials,
    elementNames,
    elementMaterials,
    elementOffsets,
    basePath,
    isAsset,
  );
  return normalized ? normalizeMesh(meshes) : meshes;
}

/// Load the texture image file and rebuild vertices and texcoords to keep the same length.
Future<List<Mesh>> _buildMesh(
  List<Vector3> vertices,
  List<Offset> texcoords,
  List<Polygon> vertexIndices,
  List<Polygon> textureIndices,
  Map<String, Material>? materials,
  List<String> elementNames,
  List<String> elementMaterials,
  List<int> elementOffsets,
  String basePath,
  bool isAsset,
) async {
  if (elementOffsets.length == 0) {
    elementNames.add('');
    elementMaterials.add('');
    elementOffsets.add(0);
  }

  final List<Mesh> meshes = <Mesh>[];
  for (int index = 0; index < elementOffsets.length; index++) {
    int faceStart = elementOffsets[index];
    int faceEnd = (index + 1 < elementOffsets.length) ? elementOffsets[index + 1] : vertexIndices.length;

    var newVertices = <Vector3>[];
    var newTexcoords = <Offset>[];
    var newIndices = <Polygon>[];
    var newTextureIndices = <Polygon>[];

    if (faceStart == 0 && faceEnd == vertexIndices.length) {
      newVertices = vertices;
      newTexcoords = texcoords;
      newIndices = vertexIndices;
      newTextureIndices = textureIndices;
    } else {
      _copyRangeIndices(faceStart, faceEnd, vertices, vertexIndices, newVertices, newIndices);
      _copyRangeIndices(faceStart, faceEnd, texcoords, textureIndices, newTexcoords, newTextureIndices);
    }

    // load texture image from assets.
    final Material? material = (materials != null) ? materials[elementMaterials[index]] : null;
    final MapEntry<String, Image>? imageEntry = await loadTexture(material, basePath);

    // fix zero texture area
    if (imageEntry != null) {
      _remapZeroAreaUVs(newTexcoords, newTextureIndices, imageEntry.value.width.toDouble(), imageEntry.value.height.toDouble());
    }

    // If a vertex has multiple different texture coordinates,
    // then create a vertex for each texture coordinate.
    _rebuildVertices(newVertices, newTexcoords, newIndices, newTextureIndices);

    final Mesh mesh = Mesh(
      vertices: newVertices,
      texcoords: newTexcoords,
      indices: newIndices,
      texture: imageEntry?.value,
      texturePath: imageEntry?.key,
      material: material,
      name: elementNames[index],
    );
    meshes.add(mesh);
  }

  return meshes;
}

/// Copy a mesh from the obj
void _copyRangeIndices<type>(int start, int end, List<type> fromVertices, List<Polygon> fromIndices, List<type> toVertices, List<Polygon> toIndices) {
  if (start < 0 || end > fromIndices.length) return;
  final faceMap = List<int?>.filled(fromVertices.length, null);
  final List<int> face = List<int>.filled(3, 0);
  for (int i = start; i < end; i++) {
    final List<int> vi = fromIndices[i].copyToArray();
    for (int j = 0; j < vi.length; j++) {
      int index = vi[j];
      if (index < 0) index = fromVertices.length - 1 + index;
      int? v = faceMap[index];
      if (v == null) {
        face[j] = toVertices.length;
        faceMap[index] = toVertices.length;
        toVertices.add(fromVertices[index]);
      } else {
        face[j] = v;
      }
    }
    toIndices.add(Polygon(face[0], face[1], face[2]));
  }
}

/// Remap the UVs when the texture area is zero.
void _remapZeroAreaUVs(List<Offset> texcoords, List<Polygon> textureIndices, double textureWidth, double textureHeight) {
  for (int index = 0; index < textureIndices.length; index++) {
    Polygon p = textureIndices[index];
    if (texcoords[p.vertex0] == texcoords[p.vertex1] && texcoords[p.vertex0] == texcoords[p.vertex2]) {
      double u = (texcoords[p.vertex0].dx * textureWidth).floorToDouble();
      double v = (texcoords[p.vertex0].dy * textureHeight).floorToDouble();
      double u1 = (u + 1.0) / textureWidth;
      double v1 = (v + 1.0) / textureHeight;
      u /= textureWidth;
      v /= textureHeight;
      int texindex = texcoords.length;
      texcoords.add(Offset(u, v));
      texcoords.add(Offset(u, v1));
      texcoords.add(Offset(u1, v));
      p.vertex0 = texindex;
      p.vertex1 = texindex + 1;
      p.vertex2 = texindex + 2;
    }
  }
}

/// Rebuild vertices and texture coordinates to keep the same length.
void _rebuildVertices(List<Vector3> vertices, List<Offset> texcoords, List<Polygon> vertexIndices, List<Polygon> textureIndices) {
  int texcoordsCount = texcoords.length;
  if (texcoordsCount == 0) return;
  List<Vector3> newVertices = <Vector3>[];
  List<Offset> newTexcoords = <Offset>[];
  HashMap<int, int?> indexMap = HashMap<int, int?>();
  for (int i = 0; i < vertexIndices.length; i++) {
    List<int> vi = vertexIndices[i].copyToArray();
    List<int> ti = textureIndices[i].copyToArray();
    List<int> face = List<int>.filled(3, 0);
    for (int j = 0; j < vi.length; j++) {
      int vIndex = vi[j];
      int tIndex = ti[j];
      int vtIndex = vIndex * texcoordsCount + tIndex;
      int? v = indexMap[vtIndex];
      if (v == null) {
        face[j] = newVertices.length;
        indexMap[vtIndex] = face[j];
        newVertices.add(vertices[vIndex].clone());
        newTexcoords.add(texcoords[tIndex]);
      } else {
        face[j] = v;
      }
    }
    vertexIndices[i].copyFromArray(face);
  }
  vertices
    ..clear()
    ..addAll(newVertices);
  texcoords
    ..clear()
    ..addAll(newTexcoords);
}

/// Calculate normal vector
Vector3 normalVector(Vector3 a, Vector3 b, Vector3 c) {
  return (b - a).cross(c - a).normalized();
}

/// Scale the model size to 1
List<Mesh> normalizeMesh(List<Mesh> meshes) {
  double maxLength = 0;
  for (Mesh mesh in meshes) {
    final List<Vector3> vertices = mesh.vertices;
    for (int i = 0; i < vertices.length; i++) {
      final storage = vertices[i].storage;
      final double x = storage[0];
      final double y = storage[1];
      final double z = storage[2];
      if (x > maxLength) maxLength = x;
      if (y > maxLength) maxLength = y;
      if (z > maxLength) maxLength = z;
    }
  }

  maxLength = 0.5 / maxLength;
  for (Mesh mesh in meshes) {
    final List<Vector3> vertices = mesh.vertices;
    for (int i = 0; i < vertices.length; i++) {
      vertices[i].scale(maxLength);
    }
  }
  return meshes;
}

// Packing all textures to a single image.
/// Reference：https://observablehq.com/@mourner/simple-rectangle-packing
///
Future<Image?> packingTexture(List<Mesh> meshes) async {
  // generate a key for a mesh.
  String getMeshKey(Mesh mesh) {
    if (mesh.texture != null) return mesh.texturePath ?? '' + mesh.textureRect.toString();
    return toColor(mesh.material.diffuse.bgr).toString();
  }

  // only pack the different textures.
  final allMeshes = meshes;
  final textures = Map<String, Mesh>();
  for (Mesh mesh in allMeshes) {
    if (mesh.vertices.length == 0) continue;
    final String key = getMeshKey(mesh);
    textures.putIfAbsent(key, () => mesh);
  }
  // if there is only one texture then return the texture directly.
  meshes = textures.values.toList();
  if (meshes.length == 1) return meshes[0].texture;
  if (meshes.length == 0) return null;

  // packing
  double area = 0;
  double maxWidth = 0;
  for (Mesh mesh in meshes) {
    area += mesh.textureRect.width * mesh.textureRect.height;
    maxWidth = math.max(maxWidth, mesh.textureRect.width);
  }
  meshes.sort((Mesh a, Mesh b) => b.textureRect.height.compareTo(a.textureRect.height));

  final double startWidth = math.max(math.sqrt(area / 0.95), maxWidth);
  final List<Rect> spaces = <Rect>[];
  spaces.add(Rect.fromLTWH(0, 0, startWidth, double.infinity));

  for (Mesh mesh in meshes) {
    for (int i = spaces.length - 1; i >= 0; i--) {
      final Rect block = mesh.textureRect;
      final Rect space = spaces[i];
      if (block.width > space.width || block.height > space.height) continue;
      mesh.textureRect = Rect.fromLTWH(space.left, space.top, block.width, block.height);
      if (block.width == space.width && block.height == space.height) {
        final Rect last = spaces.removeLast();
        if (i < spaces.length) spaces[i] = last;
      } else if (block.height == space.height) {
        spaces[i] = Rect.fromLTWH(space.left + block.width, space.top, space.width - block.width, space.height);
      } else if (block.width == space.width) {
        spaces[i] = Rect.fromLTWH(space.left, space.top + block.height, space.width, space.height - block.height);
      } else {
        spaces.add(Rect.fromLTWH(space.left + block.width, space.top, space.width - block.width, block.height));
        spaces[i] = Rect.fromLTWH(space.left, space.top + block.height, space.width, space.height - block.height);
      }
      break;
    }
  }

  // get the packed texture size
  int textureWidth = 0;
  int textureHeight = 0;
  for (Mesh mesh in meshes) {
    final Rect box = mesh.textureRect;
    if (textureWidth < box.left + box.width) textureWidth = (box.left + box.width).ceil();
    if (textureHeight < box.top + box.height) textureHeight = (box.top + box.height).ceil();
  }

  // get the pixels from mesh.texture
  final texture = Uint32List(textureWidth * textureHeight);
  for (Mesh mesh in meshes) {
    final int imageWidth = mesh.textureRect.width.toInt();
    final int imageHeight = mesh.textureRect.height.toInt();
    Uint32List pixels;
    if (mesh.texture != null) {
      final Uint32List data = await getImagePixels(mesh.texture!);
      pixels = data.buffer.asUint32List();
    } else {
      final int length = imageWidth * imageHeight;
      pixels = Uint32List(length);
      // color mode then set texture to transparent.
      final int color = 0; //mesh.material == null ? 0 : toColor(mesh.material.kd.bgr, mesh.material.d).value;
      for (int i = 0; i < length; i++) {
        pixels[i] = color;
      }
    }

    // break if the mesh.texture has changed
    if (mesh.textureRect.right > textureWidth || mesh.textureRect.bottom > textureHeight) break;

    // copy pixels from mesh.texture to texture
    int fromIndex = 0;
    int toIndex = mesh.textureRect.top.toInt() * textureWidth + mesh.textureRect.left.toInt();
    for (int y = 0; y < imageHeight; y++) {
      for (int x = 0; x < imageWidth; x++) {
        texture[toIndex + x] = pixels[fromIndex + x];
      }
      fromIndex += imageWidth;
      toIndex += textureWidth;
    }
  }

  // apply the packed textureRect to all meshes.
  for (Mesh mesh in allMeshes) {
    final String? key = getMeshKey(mesh);
    if (key != null) {
      final Rect? rect = textures[key]?.textureRect;
      if (rect != null) mesh.textureRect = rect;
    }
  }

  final c = Completer<Image>();
  decodeImageFromPixels(texture.buffer.asUint8List(), textureWidth, textureHeight, PixelFormat.rgba8888, (image) {
    c.complete(image);
  });
  return c.future;
}
