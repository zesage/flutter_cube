import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

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
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  void _onSceneCreated(Scene scene) {
    scene.camera.position.z = 10;
    scene.camera.target.y = 2;
    // from https://github.com/mikedh/trimesh
    scene.world.add(Object(scale: Vector3(5.0, 5.0, 5.0), fileName: 'assets/face-with-hair.obj'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title!),
      ),
      body: Center(
        child: Cube(
          onSceneCreated: _onSceneCreated,
        ),
      ),
    );
  }
}
