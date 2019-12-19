import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cube/cube.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Cube',
      theme: ThemeData.dark(),
      home: MyHomePage(title: 'Flutter Cube Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _onSceneCreated(Scene scene) {
    scene.camera.position.z = 35;
    scene.world.add(Object(fileName: 'assets/cube/cube.obj'));
    final random = Random();
    for (int i = 0; i < 100; i++) {
      final Object cube = Object(
        position: Vector3(
          random.nextDouble() * 30 - 15,
          random.nextDouble() * 30 - 15,
          random.nextDouble() * 30 - 15,
        ),
        rotation: Vector3(
          random.nextDouble() * 360,
          random.nextDouble() * 360,
          random.nextDouble() * 360,
        ),
        fileName: 'assets/cube/cube.obj',
      );
      scene.world.add(cube);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Cube(
          onSceneCreated: _onSceneCreated,
        ),
      ),
    );
  }
}
