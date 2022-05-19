import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_cube/model/mesh.dart';

class PLYExporter{
  static Future<String> export(List<Mesh> meshes) async {
    bool hasColor = false;
    String file = 'ply\n';
    file += 'format ascii 1.0\n';
    file += 'comment Created by Flutter\n';
    file += 'element vertex xxx\n';
    file += 'property float x\n';
    file += 'property float y\n';
    file += 'property float z\n';
    file += 'property float nx\n';
    file += 'property float ny\n';
    file += 'property float nz\n';
    for(int i = 0; i < meshes.length;i++){
      if(meshes[i].material.diffuse!=Vector3.all(0.8)){
        hasColor = true;
        break;
      }
    }
    if(hasColor){
      file += 'property uchar red\n';
      file += 'property uchar green\n';
      file += 'property uchar blue\n';
    }
    // file += 'property float s\n';
    // file += 'property float t\n';
    file += 'element face yyy\n';
    file += 'property list uchar uint vertex_indices\n';
    file += 'end_header\n';

    String polygon = '';
    int faces = 0;
    int verticies = 0;
    
    for(int i = 0; i < meshes.length;i++){
      meshes[i].calculateVertexNormals(Shading.Smooth);
      int vertexOffset = verticies;
      for(int j = 0; j < meshes[i].vertices.length;j++){
        Vector3 v = meshes[i].vertices[j];
        Vector3 n = meshes[i].normals[j];
        file += v.x.toStringAsFixed(6)+' '+v.y.toStringAsFixed(6)+' '+v.z.toStringAsFixed(6)+' '+n.x.toStringAsFixed(6)+' '+n.y.toStringAsFixed(6)+' '+n.z.toStringAsFixed(6);
        
        if(hasColor)
          file += (meshes[i].material.diffuse.x*255).ceil().toString()+' '+(meshes[i].material.diffuse.y*255).ceil().toString()+' '+(meshes[i].material.diffuse.z*255).ceil().toString();
        
        file += '\n';
        verticies++;
      }
      for(int j = 0; j < meshes[i].indices.length; j++){
        List<int> vertexes = meshes[i].indices[j].vertexes;
        polygon += '3 '+(vertexes[0]+vertexOffset).toString()+' '+(vertexes[1]+vertexOffset).toString()+' '+(vertexes[2]+vertexOffset).toString()+'\n';
        faces++;
      }
    }
    file = file.replaceAll('xxx', verticies.toString());
    file = file.replaceAll('yyy', faces.toString());
    file += polygon+'\n';

    return file;
  }
}