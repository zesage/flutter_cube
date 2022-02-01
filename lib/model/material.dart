import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'dart:ui';

class Material {
  Material()
      : name = '',
        ambient = Vector3.all(0.1),
        diffuse = Vector3.all(0.8),
        specular = Vector3.all(0.5),
        ke = Vector3.zero(),
        tf = Vector3.zero(),
        mapKa = '',
        mapKd = '',
        mapKe = '',
        mapBump = '',
        shininess = 0.8,
        ni = 0,
        opacity = 1.0,
        emissivity = 8;
  String name;
  Vector3 ambient;
  Vector3 diffuse;
  Vector3 specular;
  Vector3 ke;
  Vector3 tf;
  double shininess;
  double ni;
  double opacity;
  int emissivity;
  String mapKa;
  String mapKd;
  String mapKe;
  String mapBump;
}

/// Loading material from Material Library File (.mtl).
/// Reference：http://paulbourke.net/dataformats/mtl/
///
Future<Map<String, Material>> loadMtl(String fileName, {bool isAsset = true}) async {
  final materials = Map<String, Material>();
  
  String data;
  try {
    if (isAsset) {
      data = await rootBundle.loadString(fileName.replaceAll('\\', '/'));
    } else {
      data = await File(fileName).readAsString();
    }
  } catch (e) {
    print(e);
    return materials;
  }
  final List<String> lines = data.split('\n');

  Material material = Material();
  for (String line in lines) {
    List<String> parts = line.trim().split(RegExp(r"\s+"));
    switch (parts[0]) {
      case 'newmtl':
        material = Material();
        if (parts.length >= 2) {
          material.name = parts[1];
          materials[material.name] = material;
        }
        break;
      case 'Ka':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.ambient = v;
        }
        break;
      case 'Kd':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.diffuse = v;
        }
        break;
      case 'Ks':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.specular = v;
        }
        break;
      case 'Ke':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.ke = v;
        }
        break;
      case 'map_Ka':
        if (parts.length >= 2) {
          material.mapKa = parts.last;
        }
        break;
      case 'map_Kd':
        if (parts.length >= 2) {
          material.mapKd = parts.last;
        }
        break;
      case 'map_bump':
        if (parts.length >= 2) {
          material.mapBump = parts.last;
        }
        break;
      case 'Ns':
        if (parts.length >= 2) {
          material.shininess = double.parse(parts[1]);
        }
        break;
      case 'Ni':
        if (parts.length >= 2) {
          material.ni = double.parse(parts[1]);
        }
        break;
      case 'd':
        if (parts.length >= 2) {
          material.opacity = double.parse(parts[1]);
        }
        break;
      case 'illum':
        if (parts.length >= 2) {
          material.emissivity = int.parse(parts[1]);
        }
        break;
      default:
    }
  }
  return materials;
}

/// load an image from asset
Future<Image> loadImageFromAsset(String fileName, {bool isAsset = true, bool makeGray = false}) {
  final c = Completer<Image>();
  var dataFuture;
  if (isAsset) 
    dataFuture = rootBundle.load(fileName).then((data) => data.buffer.asUint8List());
  else 
    dataFuture = File(fileName).readAsBytes();

  dataFuture.then((data) async{
    if(makeGray){
      img.Image image = img.grayscale(img.decodeJpg(data)!);
      data = img.encodeJpg(image);
    }

    instantiateImageCodec(data).then((codec) {
      codec.getNextFrame().then((frameInfo) {
        c.complete(frameInfo.image);
      });
    });
  }).catchError((error) {
    c.completeError(error);
  });
  return c.future;
}

/// load texture from asset
Future<MapEntry<String, Image>?> loadTexture(Material? material, String basePath, {bool isAsset = true}) async {
  // get the texture file name
  bool makeGray = false;
  if (material == null) return null;
  String fileName = material.mapKa;
  if (fileName == '') fileName = material.mapKd;
  if (fileName == ''){
    fileName = material.mapBump;
    makeGray = true;
  }
  if (fileName == '') return null;

  // try to load image from asset in subdirectories
  Image? image;
  final List<String> dirList = fileName.split(RegExp(r'[/\\]+'));
  while (dirList.length > 0) {
    fileName = path.join(basePath, path.joinAll(dirList));
    try {
      image = await loadImageFromAsset(fileName, isAsset: isAsset, makeGray: makeGray);
    } catch (_) {}
    if (image != null) return MapEntry(fileName, image);
    dirList.removeAt(0);
  }
  return null;
}

Future<Uint32List> getImagePixels(Image image) async {
  final c = Completer<Uint32List>();
  image.toByteData(format: ImageByteFormat.rawRgba).then((data) {
    c.complete(data!.buffer.asUint32List());
  }).catchError((error) {
    c.completeError(error);
  });
  return c.future;
}

/// Convert Vector3 to Color
Color toColor(Vector3 v, [double opacity = 1.0]) {
  return Color.fromRGBO((v.r * 255).toInt(), (v.g * 255).toInt(), (v.b * 255).toInt(), opacity);
}

/// Convert Color to Vector3
Vector3 fromColor(Color color) {
  return Vector3(color.red / 255, color.green / 255, color.blue / 255);
}