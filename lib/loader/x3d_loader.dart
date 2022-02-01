import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Triangle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import '../model/mesh.dart';
import '../model/material.dart';

class X3DLoader{
  static int _getVertexIndex(String vIndex) {
    return int.parse(vIndex);
  }

  static List<Vector3> getVerticies(String points){
    List<String> sepPoints = points.split(RegExp(r"\s+"));
    List<Vector3> v = [];
    for(int i = 0; i < sepPoints.length-2;i=i+3){
      v.add(Vector3(double.parse(sepPoints[i]),double.parse(sepPoints[i+1]),double.parse(sepPoints[i+2])));
    }
    return v;
  }
  static List<Offset> getOffsets(String points){
    List<String> sepPoints = points.split(RegExp(r"\s+"));
    List<Offset> o = [];
    for(int i = 0; i < sepPoints.length-1;i=i+2){
      o.add(Offset(double.parse(sepPoints[i]),double.parse(sepPoints[i+1])));
    }
    return o;
  }
  static List<Triangle> getTriangles(List<List<int>> vIndi, List<List<int>> tIndi, bool hasNormals){
    List<Triangle> tri = [];
    for(int i = 0; i < vIndi.length; i++){
      List<int> indi = [vIndi[i][0],vIndi[i][1],vIndi[i][2]];
      List<int> tIn = tIndi.isNotEmpty?[tIndi[i][0],tIndi[i][1],tIndi[i][2]]:[];
      tri.add(Triangle(indi, hasNormals?indi:null, tIndi.isNotEmpty?tIn:null));
      for(int j = 3; j < vIndi[i].length;j++){
        List<int> indi = [vIndi[i][0],vIndi[i][2],vIndi[i][j]];
        List<int> tIn = tIndi.isNotEmpty?[tIndi[i][0],tIndi[i][2],tIndi[i][j]]:[];
        tri.add(Triangle(indi, hasNormals?indi:null, tIndi.isNotEmpty?tIn:null));
      }
    }
    return tri;
  }
  static List<List<int>> getIndexes(String indexes){
    List<List<int>> indi = [];
    List<String> cords = indexes.split(' -1 ');
    for(int i = 0; i < cords.length;i++){
      List<String> p = cords[i].split(RegExp(r"\s+"));
      if(p.isNotEmpty && p.length > 1){
        List<int> vi = [];
        for (int j = 0; j < p.length; j++) 
          vi.add(_getVertexIndex(p[j]));
        indi.add(vi);
      }
    }
    return indi;
  }

  /// Loading mesh from Wavefront's object file (.obj).
  /// Reference：http://paulbourke.net/dataformats/obj/
  ///
  static Future<List<Mesh>> load(String file, bool normalized, {bool isAsset = true}) async {
    Map<String, Material>? materials;
    List<Vector3> vertices = <Vector3>[];
    List<Vector3> normals = <Vector3>[];
    List<Offset> texcoords = <Offset>[];
    
    List<Triangle> tri = <Triangle>[];

    List<List<int>> vertexIndices;
    List<List<int>> textureIndices;

    List<String> elementNames = <String>[];
    List<String> elementMaterials = <String>[];

    List<int> elementOffsets = <int>[];
    String basePath = kIsWeb?'temp':path.dirname(file);

    String data;
    if (isAsset)
      data = await rootBundle.loadString(file);
    else{
      if(kIsWeb)
        data = file;//utf8.decode(file.bytes);
      else
        data = await File(file).readAsString();
    }

    String texCoords = data.split('texCoordIndex="')[1].split('"')[0];
    textureIndices = getIndexes(texCoords);
    String coordIndexes = data.split('coordIndex="')[1].split('"')[0];
    vertexIndices = getIndexes(coordIndexes);
    String vector;
    if(data.contains('vector="')){
      vector = data.split('vector="')[1].split('"')[0];
      normals = getVerticies(vector);
    }
    tri = getTriangles(vertexIndices,textureIndices,normals.isNotEmpty);
    List<String> points = data.split('point="');
    String coordPoints = points[1].split('"')[0];
    vertices = getVerticies(coordPoints);
    if(points.length > 1){
      String textPoints = points[2].split('"')[0];
      texcoords = getOffsets(textPoints);
    }
    
    final meshes = await buildMesh(
      vertices,
      normals,
      texcoords,
      tri,
      materials,
      elementNames,
      elementMaterials,
      elementOffsets,
      basePath,
      isAsset,
    );
    return normalized ? normalizeMesh(meshes) : meshes;
  }
}