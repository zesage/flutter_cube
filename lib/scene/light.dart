import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:flutter_cube/model/material.dart';

class Light {
  Light({Vector3? position, Color? color, double ambient = 0.1, double diffuse = 0.8, double specular = 0.5}) {
    position?.copyInto(this.position);
    setColor(color, ambient, diffuse, specular);
  }
  final Vector3 position = Vector3(10, 10, 0);
  final Vector3 ambient = Vector3.zero();
  final Vector3 diffuse = Vector3.zero();
  final Vector3 specular = Vector3.zero();

  void setColor(Color? color, double ambient, double diffuse, double specular) {
    final Vector3 c = (color != null) ? fromColor(color) : Vector3.all(1.0);
    this.ambient.setFrom(c * ambient);
    this.diffuse.setFrom(c * diffuse);
    this.specular.setFrom(c * specular);
  }

  Color shading(Vector3 viewPosition, Vector3 fragmentPosition, Vector3 normal, Material material) {
    final Vector3 ambient = material.ambient.clone()..multiply(this.ambient*(material.emissivity*0.1));
    final Vector3 lightDir = (viewPosition - fragmentPosition)..normalize();
    final double diff = math.max(normal.dot(lightDir), 0);
    final Vector3 diffuse = (material.diffuse * diff)..multiply(this.diffuse);
    final Vector3 viewDir = (viewPosition - fragmentPosition)..normalize();
    final Vector3 reflectDir = (-lightDir) - normal * (2 * normal.dot(-lightDir));
    final double spec = math.pow(math.max(viewDir.dot(reflectDir), 0.0), material.shininess) as double;
    final Vector3 specular = (material.specular * spec)..multiply(this.specular);
    ambient
      ..add(diffuse)
      ..add(specular)
      ..clampScalar(0, 1.0);
    return toColor(ambient, material.opacity);
  }
}
