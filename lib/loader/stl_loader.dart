import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' hide Triangle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import '../model/mesh.dart';
import '../model/material.dart';

class STLLoader{
  static Future<List<Mesh>> load(String file,bool normalized, {bool isAsset = true}) async {
    String basePath = kIsWeb?'temp':path.dirname(file);

    dynamic data;
    bool isAscii = false;

    if (isAsset){
      try{
        data = await rootBundle.loadString(file);
        isAscii = true;
      }
      catch(e){
        await rootBundle.load(file).then((value){
          data = value.buffer.asUint8List();
        });
        
      }
    }
    else{
      if(kIsWeb){
        try{
          data = utf8.encode(file);
        }
        catch(e){
          data = file;
          isAscii = true;
        }
      }
      else{
        try{
          data = await File(file).readAsString();
          isAscii = true;
        }
        catch(e){
          data = await File(file).readAsBytes();
        }
      }
    }

    if(!isAscii)
      return await STLByteLoader.load(data, basePath, normalized, isAsset);
    else
      return await STLAsciiLoader.load(data, basePath, normalized, isAsset);
  }
}

class STLAsciiLoader{
  /// Loading mesh from Wavefront's object file (.obj).
  /// Reference：http://paulbourke.net/dataformats/obj/
  ///
  static Future<List<Mesh>> load(String data, String basePath, bool normalized, bool isAsset) async {
    Map<String, Material>? materials;
    List<Vector3> vertices = <Vector3>[];
    List<Vector3> normals = <Vector3>[];
    List<Offset> texcoords = <Offset>[];
    
    List<Triangle> vertexIndices = <Triangle>[];

    List<String> elementNames = <String>[];
    List<String> elementMaterials = <String>[];

    List<int> elementOffsets = <int>[];

    final lines = data.split('\n');
    for (var line in lines) {
      List<String> parts = line.trim().split(RegExp(r"\s+"));
      switch (parts[0]) {
        case 'facet':
          Vector3 n = Vector3(double.parse(parts[2]),double.parse(parts[3]),double.parse(parts[4]));
          normals.add(n);
          normals.add(n);
          normals.add(n);
          break;
        case 'vertex':
          // the name for the group. eg: g front cube
          vertices.add(Vector3(double.parse(parts[1]),double.parse(parts[2]),double.parse(parts[3])));
          int k = vertices.length;
          if(k%3 == 0 && k != 0)
            vertexIndices.add(Triangle([k-3,k-2,k-1],[k-3,k-2,k-1],null));
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

class STLByteLoader{
  static double getDouble(List<int> temp, [int byteOffset = 0]){
    Uint8List newTemp = convertToUint8List(temp);
    return (ByteData.view(newTemp.buffer)).getFloat32(byteOffset,Endian.little);
  }

  static Uint8List convertToUint8List(List<int> temp){
    Uint8List temp2 = Uint8List(temp.length);
    for(int i = 0; i < temp.length; i++)
      temp2[i] = temp[i];
    return temp2;
  }

  static List<Vector3> getVerticies(int byteIndex, Uint8List fileBytes){
    List<Vector3> v = [];
    for(int i = 0; i < 3; i++){
      v.add(Vector3(0,0,0));
      v[i].x = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
      byteIndex += 4;
      v[i].y = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
      byteIndex += 4;
      v[i].z = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
      byteIndex += 4;
    }
    return v;
  }
  static Vector3 getNormals(int byteIndex, Uint8List fileBytes){
    Vector3 v = Vector3(0,0,0);
    v.x = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
    byteIndex += 4;
    v.y = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
    byteIndex += 4;
    v.z = getDouble([fileBytes[byteIndex], fileBytes[byteIndex + 1], fileBytes[byteIndex + 2], fileBytes[byteIndex + 3]]);
    return v;
  }
  /// Loading mesh from Wavefront's object file (.obj).
  /// Reference：http://paulbourke.net/dataformats/obj/
  ///
  static Future<List<Mesh>> load(Uint8List data, String basePath ,bool normalized, isAsset) async {
    Map<String, Material>? materials;
    List<Vector3> vertices = <Vector3>[];
    List<Vector3> normals = <Vector3>[];
    List<Offset> texcoords = <Offset>[];
    
    List<Triangle> vertexIndices = <Triangle>[];

    List<String> elementNames = <String>[];
    List<String> elementMaterials = <String>[];

    List<int> elementOffsets = <int>[];
    
    int numOfMesh = 0;
    int byteIndex = 0;

    Uint8List temp = Uint8List(4);

    /* 80 bytes title + 4 byte num of triangles + 50 bytes (1 of triangular mesh)  */
    if (data.length > 120){
      temp[0] = data[80];
      temp[1] = data[81];
      temp[2] = data[82];
      temp[3] = data[83];

      numOfMesh = (ByteData.view(temp.buffer)).getInt32(0,Endian.little);
      print(numOfMesh);
      byteIndex = 84;

      for(int i = 0; i < numOfMesh; i++){
        /* this try-catch block will be reviewed */
        /* face normal */
        Vector3 newNormals = getNormals(byteIndex, data);
        normals.add(newNormals);
        normals.add(newNormals);
        normals.add(newNormals);
        byteIndex += 12;

        List<Vector3> newVertices = getVerticies(byteIndex, data);
        vertices.add(newVertices[0]);
        vertices.add(newVertices[1]);
        vertices.add(newVertices[2]);
        vertexIndices.add(Triangle([i*3,i*3+1,i*3+2],[i*3,i*3+1,i*3+2],null));
        byteIndex += 12*3+2;
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