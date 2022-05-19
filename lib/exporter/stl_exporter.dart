import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_cube/model/mesh.dart';

class STLExporter{
  static Future<String> export(List<Mesh> meshes) async {
    String file = 'solid Exported from Flutter\n';

    for(int i = 0; i < meshes.length;i++){
      meshes[i].calculateVertexNormals(Shading.Flat);
      for(int j = 0; j < meshes[i].indices.length; j++){
        Vector3 normal = meshes[i].normals[j];
        file += 'facet normal '+normal.x.toStringAsFixed(6)+' '+normal.y.toStringAsFixed(6)+' '+normal.z.toStringAsFixed(6)+'\n';
        Vector3 v1 = meshes[i].vertices[meshes[i].indices[j].vertexes[0]];
        Vector3 v2 = meshes[i].vertices[meshes[i].indices[j].vertexes[1]];
        Vector3 v3 = meshes[i].vertices[meshes[i].indices[j].vertexes[2]];
        file += 'outer loop\n';
        file += 'vertex '+v1.x.toStringAsFixed(6)+' '+v1.y.toStringAsFixed(6)+' '+v1.z.toStringAsFixed(6)+'\n';
        file += 'vertex '+v2.x.toStringAsFixed(6)+' '+v2.y.toStringAsFixed(6)+' '+v2.z.toStringAsFixed(6)+'\n';
        file += 'vertex '+v3.x.toStringAsFixed(6)+' '+v3.y.toStringAsFixed(6)+' '+v3.z.toStringAsFixed(6)+'\n';
        file += 'endloop\n';
        file += 'endfacet\n';
      }
    }
    file += 'endsolid Exported from Flutter\n';

    return file;
  }
}