import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:vector_math/vector_math_64.dart' hide Triangle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import '../model/mesh.dart';
import '../model/material.dart';

class PLYLoader{
  static int _getVertexIndex(String vIndex) {
    return int.parse(vIndex);
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
    String basePath = kIsWeb?'temp':path.dirname(file);

    bool endedHeader = false;
    int vertexAmount = 0;
    int k = 0;
    List<String> propertyType = [];

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
        case 'property':
          // load material library file. eg: mtllib master.mtl
          propertyType.add(parts[2]);
          break;
        case 'end_header':
          // the name for the group. eg: g front cube
          endedHeader = true;
          break;
        case 'element':
          // the user-defined object name. eg: o cube
          if(parts[1] == 'vertex') vertexAmount = int.parse(parts[2]);
          break;
        default:
          if(endedHeader){
            if(k < vertexAmount){
              Vector3 v = Vector3(0,0,0);
              Vector3 n = Vector3(0,0,0);
              Vector2 t = Vector2(0,0);

              for(int i = 0; i < parts.length;i++){
                String pt = propertyType[i];
                switch (pt) {
                  case 'x':
                    v.x = double.parse(parts[i]);
                    break;
                  case 'y':
                    v.y = double.parse(parts[i]);
                    break;
                  case 'z':
                    v.z = double.parse(parts[i]);
                    break;
                  case 'nx':
                    n.x = double.parse(parts[i]);
                    break;
                  case 'ny':
                    n.y = double.parse(parts[i]);
                    break;
                  case 'nz':
                    n.z= double.parse(parts[i]);
                    break;
                  case 's':
                    t.x = double.parse(parts[i]);
                    break;
                  case 't':
                    t.y = double.parse(parts[i]);
                    break;
                  default:
                }
              }
              vertices.add(v);
              normals.add(n);
              texcoords.add(Offset(t.x,t.y));
              k++;
            }
            else{
              if(parts.length > 3){
                List<int> p = [];
                List<int> vi = [];
                List<int> indi = [_getVertexIndex(parts[1]), _getVertexIndex(parts[2]), _getVertexIndex(parts[3])];
                vertexIndices.add(Triangle(indi,indi,indi));
                vi.add(_getVertexIndex(parts[1]));
                vi.add(_getVertexIndex(parts[2]));
                vi.add(_getVertexIndex(parts[3]));
                p.add(vertexIndices.length);
                // Triangle to triangle. eg: f 1/1 2/2 3/3 4/4 ==> f 1/1 2/2 3/3 + f 1/1 3/3 4/4
                for (int i = 4; i < parts.length; i++) {
                  List<int> indi = [vertexIndices[vertexIndices.length-1].vertexes[0], vertexIndices[vertexIndices.length-1].vertexes[2], _getVertexIndex(parts[i])];
                  vertexIndices.add(Triangle(indi,indi,indi));
                  vi.add(_getVertexIndex(parts[i]));
                  p.add(vertexIndices.length);
                }
              }
            }
          }
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