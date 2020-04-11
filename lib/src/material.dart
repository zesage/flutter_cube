import 'dart:async';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'dart:ui';

class Material {
  Material()
      : name = '',
        ka = Vector3.zero(),
        kd = Vector3.zero(),
        ks = Vector3.zero(),
        ke = Vector3.zero(),
        tf = Vector3.zero(),
        mapKa = '',
        mapKd = '',
        mapKe = '',
        ns = 0,
        ni = 0,
        d = 0,
        illum = 0;
  String name;
  Vector3 ka;
  Vector3 kd;
  Vector3 ks;
  Vector3 ke;
  Vector3 tf;
  double ns;
  double ni;
  double d;
  int illum;
  String mapKa;
  String mapKd;
  String mapKe;
}

/// Loading material from Material Library File (.mtl).
/// Reference：http://paulbourke.net/dataformats/mtl/
///
Future<Map<String, Material>> loadMtl(String fileName) async {
  final materials = Map<String, Material>();
  String data;
  try {
    data = await rootBundle.loadString(fileName);
  } catch (_) {
    return materials;
  }
  final List<String> lines = data.split('\n');

  Material material;
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
          material.ka = v;
        }
        break;
      case 'Kd':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.kd = v;
        }
        break;
      case 'Ks':
        if (parts.length >= 4) {
          final v = Vector3(double.parse(parts[1]), double.parse(parts[2]), double.parse(parts[3]));
          material.ks = v;
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
      case 'Ns':
        if (parts.length >= 2) {
          material.ns = double.parse(parts[1]);
        }
        break;
      case 'Ni':
        if (parts.length >= 2) {
          material.ni = double.parse(parts[1]);
        }
        break;
      case 'd':
        if (parts.length >= 2) {
          material.d = double.parse(parts[1]);
        }
        break;
      case 'illum':
        if (parts.length >= 2) {
          material.illum = int.parse(parts[1]);
        }
        break;
      default:
    }
  }
  return materials;
}

/// load an image from asset
Future<Image> loadImageFromAsset(String fileName) {
  final c = Completer<Image>();
  rootBundle.load(fileName).then((data) {
    instantiateImageCodec(data.buffer.asUint8List()).then((codec) {
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
Future<MapEntry<String, Image>> loadTexture(Material material, String basePath) async {
  // get the texture file name
  if (material == null) return null;
  String fileName = material.mapKa;
  if (fileName == '') fileName = material.mapKd;
  if (fileName == '') return null;

  // try to load image from asset in subdirectories
  Image image;
  final List<String> dirList = fileName.split(RegExp(r'[/\\]+'));
  while (dirList.length > 0) {
    fileName = path.join(basePath, path.joinAll(dirList));
    try {
      image = await loadImageFromAsset(fileName);
    } catch (_) {}
    if (image != null) return MapEntry(fileName, image);
    dirList.removeAt(0);
  }
  return null;
}

Future<Uint32List> getImagePixels(Image image) async {
  final c = Completer<Uint32List>();
  image.toByteData(format: ImageByteFormat.rawRgba).then((data) {
    c.complete(data.buffer.asUint32List());
  }).catchError((error) {
    c.completeError(error);
  });

  return c.future;
}

/// Convert Vector3 to Color
Color toColor(Vector3 v, [double opacity = 1.0]) {
  return Color.fromRGBO((v.r * 255).toInt(), (v.g * 255).toInt(), (v.b * 255).toInt(), opacity);
}
