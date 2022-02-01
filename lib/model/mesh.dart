import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'material.dart';

enum SubdivideSurface{Catmull_Clark,Catmull_Clark_Simple}
enum Shading{Flat,Smooth}

class Vertex{
  Vertex({
    required this.indicies,
    required this.vertex
  });

  List<Vector3> vertex;
  List<Triangle> indicies;
}

class Triangle{
  Triangle(this.vertexes,this.normals,this.texture,[this.z = 0, this.showFace = false]);
  List<int> vertexes;
  List<int>? normals;
  List<int>? texture;

  double z;
  bool showFace;

  List<int> copyVertexes() => vertexes;
  List<int>? copyNormals() => normals;
  List<int>? copyTextures() => texture;
  void copyFromArray(List<int> array) {
    vertexes = array;
    normals = array;
    texture = array;
  }
}

class Mesh {
  Mesh({
    List<Vector3>? vertices,
    List<Vector3>? normals, 
    List<Offset>? texcoords, 
    List<Triangle>? indices,
    List<Color>? colors,
    this.texture, 
    Rect? textureRect, 
    this.texturePath, 
    Material? material, 
    this.name
  }) {
    this.vertices = vertices ?? <Vector3>[];
    this.normals = normals ?? <Vector3>[];
    this.texcoords = texcoords ?? <Offset>[];
    this.colors = colors ?? <Color>[];
    this.indices = indices ?? <Triangle>[];
    this.material = material ?? Material();
    this.textureRect = textureRect ?? Rect.fromLTWH(0, 0, texture==null?1.0:texture!.width.toDouble(), texture==null?1.0:texture!.height.toDouble());
  }
  late List<Vector3> vertices;
  late List<Vector3> normals;
  late List<Offset> texcoords;
  late List<Color> colors;
  late List<Triangle> indices;
  Image? texture;
  late Rect textureRect;
  String? texturePath;
  late Material material;
  String? name;
  /// Calculate new normals using shading types Flat or Smooth
  void calculateVertexNormals(Shading type){
    Vertex temp = _calculateVertexNormals(vertices,indices,type);
    this.normals = temp.vertex;
  }
  /// Remove normals
  void removeNormals(){
    this.normals = [];
  }
  /// Remove duplicate verticies from mesh
  void removeDuplicateVertices(){
    Vertex temp = _removeDuplicates(vertices, indices);
    this.indices = temp.indicies;
    this.vertices = temp.vertex;
  }
}

/// Load the texture image file and rebuild vertices and texcoords to keep the same length.
Future<List<Mesh>> buildMesh(
  List<Vector3> vertices,
  List<Vector3> normals,
  List<Offset> texcoords,
  List<Triangle> triangles,
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
    int faceEnd = (index + 1 < elementOffsets.length) ? elementOffsets[index + 1] : triangles.length;

    var newVertices = <Vector3>[];
    var newNormals = <Vector3>[];
    var newTexcoords = <Offset>[];
    var newTriangles = <Triangle>[];

    if (faceStart == 0 && faceEnd == triangles.length) {
      newVertices = vertices;
      newNormals = normals;
      newTexcoords = texcoords;
      newTriangles = triangles;
    } 
    else
      _copyRangeIndices(faceStart, faceEnd, vertices, normals, texcoords ,triangles, newVertices, newNormals, newTexcoords, newTriangles);

    // load texture image from assets.
    final Material? material = (materials != null) ? materials[elementMaterials[index]] : null;
    final MapEntry<String, Image>? imageEntry = await loadTexture(material, basePath,isAsset: false);

    // fix zero texture area
    if (imageEntry != null) 
      _remapZeroAreaUVs(newTexcoords, newTriangles, imageEntry.value.width.toDouble(), imageEntry.value.height.toDouble());

    // If a vertex has multiple different texture coordinates,
    // then create a vertex for each texture coordinate.
    _rebuildVertices(newVertices, newNormals, newTexcoords, newTriangles);
    final Mesh mesh = Mesh(
      vertices: newVertices,
      normals: newNormals,
      texcoords: newTexcoords,
      indices: newTriangles,
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
void _copyRangeIndices(
  int start, 
  int end, 
  List<Vector3> fromVertices, 
  List<Vector3> fromNormals, 
  List<Offset> fromText,
  List<Triangle> fromIndices, 
  List<Vector3> toVertices, 
  List<Vector3> toNormals, 
  List<Offset> toText,
  List<Triangle> toIndices
) {
  if (start < 0 || end > fromIndices.length) return;
  final viMap = List<int?>.filled(fromVertices.length, null);
  final niMap = List<int?>.filled(fromNormals.length, null);
  final tiMap = List<int?>.filled(fromText.length, null);

  bool processNi = niMap.isNotEmpty;
  bool processTi = tiMap.isNotEmpty;

  for (int i = start; i < end; i++) {
    final List<int> newVi = List<int>.filled(fromIndices[i].vertexes.length, 0);
    final List<int> newNi = processNi?List<int>.filled(fromIndices[i].normals!.length, 0):[];
    final List<int> newTi = processTi?List<int>.filled(fromIndices[i].texture!.length, 0):[];

    final List<int> vi = fromIndices[i].copyVertexes();
    final List<int>? ni = fromIndices[i].copyNormals();
    final List<int>? ti = fromIndices[i].copyTextures();

    for (int j = 0; j < vi.length; j++) {
      //vert
      int indexV = vi[j];
      int indexN = processNi?ni![j]:0;
      int indexT = processTi?ti![j]:0;

      if (indexV < 0) indexV = fromVertices.length - 1 + indexV;
      if (indexN < 0) indexN = fromNormals.length - 1 + indexN;
      if (indexT < 0) indexT = fromText.length - 1 + indexT;

      int? v = viMap[indexV];
      int? n = processNi?niMap[indexN]:null;
      int? t = processTi?tiMap[indexT]:null;

      if (v == null) {
        newVi[j] = toVertices.length;
        viMap[indexV] = toVertices.length;
        toVertices.add(fromVertices[indexV]);
      }
      else
        newVi[j] = v;
      
      if(n == null && processNi){
        newNi[j] = toNormals.length;
        niMap[indexN] = toNormals.length;
        toNormals.add(fromNormals[indexN]);
      }
      else if(processNi)
        newNi[j] = n!;

      if(t == null && processTi){
        newTi[j] = toText.length;
        tiMap[indexT] = toText.length;
        toText.add(fromText[indexT]);
      }
      else if(processTi)
        newTi[j] = t!;
      
    }
    toIndices.add(Triangle(newVi,newNi,newTi));
  }
}

/// Remap the UVs when the texture area is zero.
void _remapZeroAreaUVs(List<Offset> texcoords, List<Triangle> textureIndices, double textureWidth, double textureHeight) {
  for (int index = 0; index < textureIndices.length; index++) {
    Triangle p = textureIndices[index];
    if (texcoords[p.texture![0]] == texcoords[p.texture![1]] && texcoords[p.texture![0]] == texcoords[p.texture![2]]) {
      double u = (texcoords[p.texture![0]].dx * textureWidth).floorToDouble();
      double v = (texcoords[p.texture![0]].dy * textureHeight).floorToDouble();
      double u1 = (u + 1.0) / textureWidth;
      double v1 = (v + 1.0) / textureHeight;
      u /= textureWidth;
      v /= textureHeight;
      int texindex = texcoords.length;
      texcoords.add(Offset(u, v));
      texcoords.add(Offset(u, v1));
      texcoords.add(Offset(u1, v));
      for(int j = 0; j < p.texture!.length;j++)
        p.texture![j] = texindex+j;
    }
  }
}

/// Rebuild vertices and texture coordinates to keep the same length.
void _rebuildVertices(List<Vector3> vertices, List<Vector3> normals, List<Offset> texcoords, List<Triangle> vertexIndices) {
  int texcoordsCount = texcoords.length;
  if (texcoordsCount == 0) return;
  List<Vector3> newVertices = <Vector3>[];
  List<Vector3> newNormals = <Vector3>[];
  List<Offset> newTexcoords = <Offset>[];
  HashMap<int, int> indexMap = HashMap<int, int>();
  for (int i = 0; i < vertexIndices.length; i++) {
    List<int> vi = vertexIndices[i].copyVertexes();
    List<int>? vn = vertexIndices[i].copyNormals();
    List<int>? ti = vertexIndices[i].copyTextures();
    List<int> face = List<int>.filled(vi.length, 0);
    for (int j = 0; j < vi.length; j++) {
      int vIndex = vi[j];
      int? vnIndex = vn != null?vn[j]:null;
      int tIndex = ti![j];
      int vtIndex = vIndex * texcoordsCount + tIndex;
      int? v = indexMap[vtIndex];
      if (v == null) {
        face[j] = newVertices.length;
        indexMap[vtIndex] = face[j];
        newVertices.add(vertices[vIndex].clone());
        if(vnIndex!=null)newNormals.add(normals[vnIndex].clone());
        newTexcoords.add(texcoords[tIndex]);
      } 
      else 
        face[j] = v;
    }
    vertexIndices[i].copyFromArray(face);
  }
  vertices
    ..clear()
    ..addAll(newVertices);
  if(newNormals.isNotEmpty)normals
    ..clear()
    ..addAll(newNormals);
  texcoords
    ..clear()
    ..addAll(newTexcoords);
}

Vertex _calculateVertexNormals(List<Vector3> vertices,List<Triangle> indices, Shading shading){
  if(shading == Shading.Flat)
    return _calculateFlatVertexNormals(vertices,indices);
  else
    return _calculateSmoothVertexNormals(vertices,indices);
}
Vertex _calculateFlatVertexNormals(List<Vector3> vertices,List<Triangle> indices){
  List<Vector3> vN = [];
  List<Triangle> vertexIndicies = [];

  Vector3 normalizeFace(int face) {
    Vector3 faceNormal;

    Vector3 ver1 = vertices[indices[face].vertexes[0]];
    Vector3 ver2 = vertices[indices[face].vertexes[1]];
    Vector3 ver3 = vertices[indices[face].vertexes[2]];
    List<double> x = [ver1[0],ver2[0],ver3[0]];
    List<double> y = [ver1[1],ver2[1],ver3[1]];
    List<double> z = [ver1[2],ver2[2],ver3[2]];

    Vector3 P1 = Vector3(x[0],y[0],z[0]);
    Vector3 P2 = Vector3(x[1],y[1],z[1]);
    Vector3 P3 = Vector3(x[2],y[2],z[2]);

    Vector3 V = P2-P1;
    Vector3 W = P3-P1;
    Vector3 N = V.cross(W);

    faceNormal = N..normalize();
    
    return (faceNormal*3)..normalize();
  }

  for(int j = 0; j < indices.length;j++){
    Vector3 nor = normalizeFace(j);
    vN.add(nor);
    vertexIndicies.add(
      Triangle(indices[j].vertexes,[vN.length-1,vN.length-1,vN.length-1],indices[j].texture)
    );
  }

  return Vertex(indicies: vertexIndicies,vertex: vN);
}
Vertex _calculateSmoothVertexNormals(List<Vector3> vertices,List<Triangle> indices){
  List<Vector3> vN = [];
  List<Triangle> vertexIndicies = [];

  List<int> findFaces(Vector3 i){
    List<int> newInd = [];
    for(int j = 0; j < indices.length; j++){
      for(int k = 0; k < indices[j].vertexes.length;k++){
        int location = indices[j].vertexes[k];
        if(vertices[location] == i)
          newInd.add(j);
      }
    }
    return newInd;
  }

  List<Vector3> normalizeFaces(List<int> faces) {
    List<Vector3> faceNormals = [];
    for(int i = 0; i < faces.length; i++){
      Vector3 ver1 = vertices[indices[faces[i]].vertexes[0]];
      Vector3 ver2 = vertices[indices[faces[i]].vertexes[1]];
      Vector3 ver3 = vertices[indices[faces[i]].vertexes[2]];
      List<double> x = [ver1[0],ver2[0],ver3[0]];
      List<double> y = [ver1[1],ver2[1],ver3[1]];
      List<double> z = [ver1[2],ver2[2],ver3[2]];

      Vector3 P1 = Vector3(x[0],y[0],z[0]);
      Vector3 P2 = Vector3(x[1],y[1],z[1]);
      Vector3 P3 = Vector3(x[2],y[2],z[2]);

      Vector3 V = P2-P1;
      Vector3 W = P3-P1;
      Vector3 N = V.cross(W);

      faceNormals.add(N..normalize());
    }
    return faceNormals;
  }

  Vector3 vertexNormal(List<Vector3> faceNormals){
    Vector3 vn = faceNormals[0];
    for(int i = 1; i < faceNormals.length; i++)
      vn += faceNormals[i];
    return (vn)..normalize();
  }

  for(int i = 0; i < vertices.length; i++){
    List<int> faces = findFaces(vertices[i]);
    List<Vector3> faceNormals = normalizeFaces(faces);
    vN.add(vertexNormal(faceNormals));
    vertexIndicies.add(Triangle(indices[i].vertexes, indices[i].vertexes, null));
  }

  return Vertex(indicies: vertexIndicies, vertex: vN);
}

Vertex _removeDuplicates(List<Vector3> fromVertices,List<Triangle> fromIndices){
  List<Triangle> toIndices = [];
  List<Vector3> toVertices = fromVertices.toSet().toList();

  for(int i = 0; i < fromIndices.length;i++){
    List<int> vertexes = [];
    List<int> normals = [];
    List<int> texture = [];
    for(int j = 0; j < fromIndices[i].vertexes.length; j++){
      for(int k = 0; k < toVertices.length;k++){
        if(fromVertices[fromIndices[i].vertexes[j]] == toVertices[k]){
          vertexes.add(k);
          texture.add(k);
          normals.add(k);
        }
      }
    }
    toIndices.add(
      Triangle(vertexes,normals,texture)
    );
  }
  return Vertex(
    vertex: toVertices,
    indicies: toIndices
  );
}


/// Calcunormal vector
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
    } 
    else {
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
