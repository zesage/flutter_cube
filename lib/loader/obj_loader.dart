import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Triangle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import '../model/mesh.dart';
import '../model/material.dart';

class OBJLoader{
  static int _getVertexIndex(String vIndex) {
    if (int.parse(vIndex) < 0)
      return int.parse(vIndex) + 1;
    else
      return int.parse(vIndex) - 1;
  }


  /// Loading mesh from Wavefront's object file (.obj).
  /// Reference：http://paulbourke.net/dataformats/obj/
  ///
  static Future<List<Mesh>> load(String file, bool normalized, {bool isAsset = true}) async {
    Map<String, Material>? materials;
    List<Vector3> vertices = <Vector3>[];
    List<Vector3> normals = <Vector3>[];
    List<Offset> texcoords = <Offset>[];
    
    List<Triangle> vertexIndices = <Triangle>[];

    List<String> elementNames = <String>[];
    List<String> elementMaterials = <String>[];

    List<int> elementOffsets = <int>[];

    String? materialName;
    String? objectlName;
    String? groupName;
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
        case 'vn':
          // a geometric vertex normals and its x y z coordinates. eg: vn 0.000000 2.000000 0.000000
          if (parts.length >= 4) {
            final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
            normals.add(v);
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
            // eg:f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3; f v1 v2 v3; f v1/vt1 v2/vt2 v3/vt3; f v1//vn1 v2//vn2 v3//vn3; 
            List<List<String>> p = [];
            for(int split = 1; split < parts.length;split++){
              p.add(parts[split].split('/'));
            }

            if (parts.length >= 3) {
              //Convert to triangles
              List<int>? ti;
              if ((p[0].length > 1 && p[0][1] != '') && (p[1].length > 1 && p[1][1] != '') && (p[2].length > 1 && p[2][1] != ''))
                ti = [_getVertexIndex(p[0][1]), _getVertexIndex(p[1][1]), _getVertexIndex(p[2][1])];

              List<int>? nv;
              if ((p[0].length > 2 && p[0][2] != '') && (p[1].length > 2 && p[1][2] != '') && (p[2].length > 2 && p[2][2] != ''))
                nv = [_getVertexIndex(p[0][2]), _getVertexIndex(p[1][2]), _getVertexIndex(p[2][2])];

              vertexIndices.add(
                Triangle(
                  [_getVertexIndex(p[0][0]), _getVertexIndex(p[1][0]), _getVertexIndex(p[2][0])],
                  nv,ti
                )
              );

              // Triangle to triangle. eg: f 1/1 2/2 3/3 4/4 ==> f 1/1 2/2 3/3 + f 1/1 3/3 4/4
              if(p.length > 3)
              for (int i = 3; i < p.length; i++) {
                //final List<String> p3 = p[i].split('/');
                List<int> vi = [vertexIndices[vertexIndices.length-1].vertexes[0], vertexIndices[vertexIndices.length-1].vertexes[2], _getVertexIndex(p[i][0])];
                if (p[i].length > 1 && p[i][1] != '') 
                  ti = [vertexIndices[vertexIndices.length-1].texture![0], vertexIndices[vertexIndices.length-1].texture![2], _getVertexIndex(p[i][1])];
                if (p[i].length > 2 && p[i][2] != '')
                  nv = [vertexIndices[vertexIndices.length-1].normals![0], vertexIndices[vertexIndices.length-1].normals![2], _getVertexIndex(p[i][2])];
                vertexIndices.add(Triangle(vi,nv,ti));
              }
            }
          break;
        default:
      }
    }
    final meshes = await buildMesh(
      vertices,
      normals,
      texcoords,
      vertexIndices,
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