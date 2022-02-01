import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

class GenerateMesh{
  static Future<Mesh> generateSphere({
    num radius = 0.5, 
    int latSegments = 32, 
    int lonSegments = 64, 
    String? texturePath
  }) async {
    int count = (latSegments + 1) * (lonSegments + 1);
    List<Vector3> vertices = List<Vector3>.filled(count, Vector3.zero());
    List<Offset> texcoords = List<Offset>.filled(count, Offset.zero);
    //List<Polygon> indices = List<Polygon>.filled(latSegments * lonSegments * 2, Polygon([0, 0, 0]));

    int i = 0;
    for (int y = 0; y <= latSegments; ++y) {
      final double v = y / latSegments;
      final double sv = math.sin(v * math.pi);
      final double cv = math.cos(v * math.pi);
      for (int x = 0; x <= lonSegments; ++x) {
        final double u = x / lonSegments;
        vertices[i] = Vector3(radius * math.cos(u * math.pi * 2.0) * sv, radius * cv, radius * math.sin(u * math.pi * 2.0) * sv);
        texcoords[i] = Offset(1.0 - u, 1.0 - v);
        i++;
      }
    }

    i = 0;
    for (int y = 0; y < latSegments; ++y) {
      final int base1 = (lonSegments + 1) * y;
      final int base2 = (lonSegments + 1) * (y + 1);
      // for (int x = 0; x < lonSegments; ++x) {
      //   indices[i++] = Polygon([base1 + x, base1 + x + 1, base2 + x]);
      //   indices[i++] = Polygon([base1 + x + 1, base2 + x + 1, base2 + x]);
      // }
    }
    Mesh mesh;
    if(texturePath != null){
      ui.Image texture = await loadImageFromAsset(texturePath);
      mesh = Mesh(
        vertices: vertices, 
        texcoords: texcoords, 
        //indices: indices, 
        texture: texture, 
        texturePath: texturePath
      );
    }
    else{
      mesh = Mesh(
        vertices: vertices, 
        //indices: indices, 
      );
    }
    return mesh;
  }

  static Future<Mesh> generatePlane({
    double size = 0.1,
    int latSegments = 32, 
    int lonSegments = 64, 
    String? texturePath
  }) async {
    int count = (latSegments + 1) * (lonSegments + 1);
    List<Vector3> vertices = List<Vector3>.filled(count, Vector3.zero());
    List<Offset> texcoords = List<Offset>.filled(count, Offset.zero);
    //List<Polygon> indices = List<Polygon>.filled(latSegments * lonSegments * 2, Polygon([0, 0, 0]));

    int i = 0;
    for (int y = 0; y <= latSegments; ++y) {
      final double v = y / latSegments;
      final double sv = v;
      final double cv = v;
      for (int x = 0; x <= lonSegments; ++x) {
        final double u = x / lonSegments;
        vertices[i] = Vector3(y*size, x*size, 0);
        texcoords[i] = Offset(1.0 - u, 1.0 - v);
        i++;
      }
    }

    i = 0;
    for (int y = 0; y < latSegments; ++y) {
      final int base1 = (lonSegments + 1) * y;
      final int base2 = (lonSegments + 1) * (y + 1);
      for (int x = 0; x < lonSegments; ++x) {
        //indices[i++] = Polygon([base1 + x, base1 + x + 1, base2 + x]);
        //indices[i++] = Polygon([base1 + x + 1, base2 + x + 1, base2 + x]);
      }
    }
    Mesh mesh;
    if(texturePath != null){
      ui.Image texture = await loadImageFromAsset(texturePath);
      mesh = Mesh(
        vertices: vertices, 
        texcoords: texcoords, 
        //indices: indices, 
        texture: texture, 
        texturePath: texturePath
      );
    }
    else{
      mesh = Mesh(
        vertices: vertices, 
        //indices: indices, 
      );
    }
    return mesh;
  }
}