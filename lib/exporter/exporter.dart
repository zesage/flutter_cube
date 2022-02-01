import 'dart:io';
import 'dart:ui';

import 'package:flutter_cube/exporter/obj_exporter.dart';
import 'package:flutter_cube/exporter/stl_exporter.dart';
import 'package:flutter_cube/exporter/x3d_exporter.dart';
import 'package:flutter_cube/exporter/ply_exporter.dart';
import 'package:flutter_cube/exporter/svg_exporter.dart';
import 'package:flutter_cube/flutter_cube.dart';

enum ExporterType{stl,obj,ply,svg,x3d,png}

class ObjectExporter{
  static List<Mesh> getMeshes(Object obj){
    List<Mesh> meshes = [];
    print(obj.children.length);
    if(obj.children.isNotEmpty)
      for(int i = 0; i < obj.children.length;i++){
        if(obj.children[i].children.isNotEmpty){
          for(int j = 0; j < obj.children[i].children.length;j++){
            meshes.add(obj.children[i].children[j].mesh);
          }
        }
        else{
          meshes.add(obj.children[i].mesh);
        }
      }
    else
      meshes.add(obj.mesh);
    return meshes;
  }
  static void export(ExporterType type, String filePath, Scene scene){
    List<Mesh> meshes = getMeshes(scene.world);
    switch (type) {
      case ExporterType.svg:
        SVGExporter.export(scene).then((data){
          _writeToFile(filePath, data);
        });
        break;
      case ExporterType.stl:
        STLExporter.export(meshes).then((data){
          _writeToFile(filePath, data);
        });
        break;
      case ExporterType.obj:
        List<String> fileName = filePath.split('.')[1].split('\\');
        OBJExporter.export(fileName.last,meshes).then((data){
          _writeToFile(filePath, data);
        });
        break;
      case ExporterType.ply:
        PLYExporter.export(meshes).then((data){
          _writeToFile(filePath, data);
        });
        break;
      case ExporterType.x3d:
        X3DExporter.export(meshes).then((data){
          _writeToFile(filePath, data);
        });
        break;
      case ExporterType.png:
        _exportPNG(filePath, scene);
        break;
      default:
    }
  }
  static Future<void> _exportPNG(String filePath, Scene scene) async{
    await scene.generateImage(Size(scene.camera.viewportWidth, scene.camera.viewportHeight)).then((value){
      value.toByteData(format: ImageByteFormat.png).then((value){
        File(filePath).writeAsBytesSync(value!.buffer.asUint8List());
      });
    });
  }
  static Future<void> _writeToFile(String path, String data){
    final file = File(path);
    return file.writeAsString(data);
  }
}