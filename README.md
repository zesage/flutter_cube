# Flutter Cube

[![pub package](https://img.shields.io/pub/v/flutter_cube.svg)](https://pub.dev/packages/flutter_cube)
A Flutter 3D widget that renders Wavefront's object files.

## Getting Started

Add flutter_cube as a dependency in your pubspec.yaml file.

```yaml
dependencies:
  flutter_cube: ^0.0.1
```

Add Wavefront's object files to assets.

```yaml
flutter:
  assets:
    - assets/cube/cube.obj
    - assets/cube/cube.mtl
    - assets/cube/flutter.png
```

```dart
import 'package:flutter_cube/flutter_cube.dart';
... ...
  
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Cube(
          onSceneCreated: (Scene scene) {
            scene.world.add(Object(fileName: 'assets/cube/cube.obj'));
          },
        ),
      ),
    );
  }
```

## Screenshot

![screenshot](https://github.com/zesage/flutter_cube/raw/master/resource/screenshot.gif)
