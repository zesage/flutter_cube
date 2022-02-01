import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_cube/model/mesh.dart';

class OBJExporter{
  static Future<String> export(String fileName,List<Mesh> meshes) async {
    String file = "# Flutter OBJ File: ''\n";
    file += 'mtllib '+fileName+'.mtl\n';
    int vertexOffset = 1;
    int normalOffset = 1;
    for(int i = 0; i < meshes.length;i++){
      file += 'o Object.'+(i+1).toString()+'\n';
      bool hasNormals = false;
      for(int j = 0 ; j < meshes[i].vertices.length;j++){
        Vector3 v = meshes[i].vertices[j];
        file += 'v '+v.x.toStringAsFixed(6)+' '+v.y.toStringAsFixed(6)+' '+v.z.toStringAsFixed(6)+'\n';
      }
      if(meshes[i].normals.isNotEmpty)
        for(int j = 0; j < meshes[i].normals.length;j++){
          hasNormals = true;
          Vector3 n = meshes[i].normals[j];
          file += 'vn '+n.x.toStringAsFixed(6)+' '+n.y.toStringAsFixed(6)+' '+n.z.toStringAsFixed(6)+'\n';
        }
      file += 'usemtl None\ns 1\n';
      for(int j = 0; j < meshes[i].indices.length; j++){
        List<int> v = meshes[i].indices[j].vertexes;
        if(hasNormals){
          // List<int> n = meshes[i].vnormals[j].vertexes;
          // file += 'f '+(v[0]+vertexOffset).toString()+'//'+(n[0]+normalOffset).toString()+' '
          //   +(v[1]+vertexOffset).toString()+'//'+(n[1]+normalOffset).toString()+' '
          //   +(v[2]+vertexOffset).toString()+'//'+(n[2]+normalOffset).toString()+'\n';
        }
        else
          file += 'f '+(v[0]+vertexOffset).toString()+' '+(v[1]+vertexOffset).toString()+' '+(v[2]+vertexOffset).toString()+'\n';
      }
      
      vertexOffset += meshes[i].vertices.length;
      normalOffset += meshes[i].normals.length;
    }
    file += '\n';

    return file;
  }
}