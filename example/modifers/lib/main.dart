import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'dart:async';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: const MyHomePage(title: 'Flutter Cube Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Scene? _scene;
  int illum = 45;

  int? finalSelectedObject;
  int? finalSelectedChild;
  String? tappedObject;
  Timer? clickedTimer;
  String? clickedName;
  final double _ambient = 0.8;
  final double _diffuse = 0.5;
  final double _specular = 0.5;
  final double _shininess = 0.0;

  @override
  void initState() {
    super.initState();
  }
  @override
  void dispose() {
    clickedTimer?.cancel();
    super.dispose();
  }

  void _onSceneCreated(Scene scene) {
    scene.camera.position.z = 20;
    scene.camera.position.y = -1;
    scene.camera.pan.y = -1;
    scene.camera.target.y = 0;
    scene.light.position.setFrom(Vector3(0, 0, 10));
    scene.rayCasting = true;
    scene.camera.cameraControls = CameraControls(
      panX: true,
      panY: true,
      orbitX: true,
      orbitY: true,
      zoom: true
    );
    scene.light.setColor(Colors.white, _ambient, _diffuse, _specular);
    scene.world.add(Object(
      position: Vector3(0, 0, 0), 
      rotation: Vector3(0,10,90),
      scale: Vector3(10.0, 10.0, 10.0), 
      fileName: 'assets/sphere.obj',
      number: 0,
      name: 'Sphere',
      backfaceCulling: true, 
      lighting: true, 
      showVerts: false,
      xray: false,
    ));
    _scene = scene;
    setState(() {});
  }
  void cubeCallback({CubeCallbacks? call, Offset? details}){
    switch (call) {
      case CubeCallbacks.OnTap:
        setState(() {
          checkTappedObject(_scene!.clickedObject(),false);
          tappedObject = _scene!.clickedObject();
        });
        break;
      case CubeCallbacks.RemoveObject:
        break;
      default:
    }
  }
  void changeObjectEmissivity(){
    if(finalSelectedChild != null && finalSelectedObject != null){
      _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.material.emissivity = illum;
    }
    else if(finalSelectedObject != null){
      _scene!.world.children[finalSelectedObject!].mesh.material.emissivity = illum;
    }
    setState(() {});
  }
  void changeObjectColor(Vector3 color){
    if(finalSelectedChild != null && finalSelectedObject != null){
      _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.material.diffuse = color;
    }
    else if(finalSelectedObject != null){
      _scene!.world.children[finalSelectedObject!].mesh.material.diffuse = color;
    }
    setState(() {});
  }
  Color currentColor(){
    Vector3 color = Vector3(0,0,0);
    if(finalSelectedChild != null && finalSelectedObject != null){
      color = _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.material.diffuse;
    }
    else if(finalSelectedObject != null){
      color = _scene!.world.children[finalSelectedObject!].mesh.material.diffuse;
    }
    return toColor(color);
  }
  void checkTappedObject(String? tappedObject,bool hovering){
    int? i;
    int? j;
    for(int k = 0; k < _scene!.world.children.length; k++){
      if(_scene!.world.children[k].children.isNotEmpty){
        for(int l = 0; l < _scene!.world.children[k].children.length;l++){
          if(_scene!.world.children[k].children[l].name == tappedObject){
            i = k;
            j = l;
          }
          else if(_scene!.world.children[k].name == tappedObject){
            i = k;
          }
        }
      }
      else{
        if(_scene!.world.children[k].name == tappedObject){
          i = k;
        }
      }
    }
    if(!hovering){
      finalSelectedObject = i;
      finalSelectedChild = j;
    }
  }
  Widget objectBox(String name, bool child){
    return Container(
        padding: const EdgeInsets.only(left: 10,right: 10),
        height: 25,
        width: 120,
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          boxShadow: [BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 5,
            offset: const Offset(0,2),
          ),]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              InkWell(
                onTap: (){
                  setState(() {
                    if(name == 'Wireframe'){
                      _scene!.showWireframe = !_scene!.showWireframe;
                    }
                    else if(name == 'X-Ray'){
                      _scene!.xray = !_scene!.xray;
                    }
                    else if(name == 'Texture'){
                      _scene!.showTexture = !_scene!.showTexture;
                    }
                    else{
                      _scene!.showVerticies = !_scene!.showVerticies;
                    }
                  });
                },
                child: Icon(
                  (child)?Icons.check_box_outlined:Icons.check_box_outline_blank,
                  size: 18,
                )
              ),
              Container(
                margin: const EdgeInsets.only(left: 10),
                //width: _width-85,
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                )
              ),
          ],),
        ],)
      );
  }
  Widget objectButton(String name){
    return Container(
      margin: const EdgeInsets.all(5),
      child: InkWell(
        onTap: (){
          Duration time = const Duration(seconds: 1);
          setState(() {
            clickedName = name;
          });
          clickedTimer = Timer(time,(){
            setState(() {
              clickedName = null;
              clickedTimer?.cancel();
            });
          });
          if(name == 'Remove Duplicates'){
            if(_scene!.world.children.isNotEmpty){
              if(finalSelectedChild != null && finalSelectedObject != null){
                _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.removeDuplicateVertices();
              }
              else if(finalSelectedObject != null){
                _scene!.world.children[finalSelectedObject!].mesh.removeDuplicateVertices();
              }
            }
          }
          else if(name == 'Change Color'){
            changeColor(context, currentColor()).then((value){
              if(value != null){
                changeObjectColor(fromColor(value));
              }
            });
          }
          else if(name == 'Seperate By Loose Parts'){
            if(_scene!.world.children.isNotEmpty){
              if(finalSelectedChild != null && finalSelectedObject != null){
                _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].seperateByLooseParts();
              }
              else if(finalSelectedObject != null){
                _scene!.world.children[finalSelectedObject!].seperateByLooseParts();
              }
            }
          }
          else{
            if(_scene!.world.children.isNotEmpty){
              if(finalSelectedChild != null && finalSelectedObject != null){
                if(name == 'Smooth Shading'){
                  _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.calculateVertexNormals(Shading.Smooth);
                }
                else{
                  _scene!.world.children[finalSelectedObject!].children[finalSelectedChild!].mesh.calculateVertexNormals(Shading.Flat);
                }
              }
              else if(finalSelectedObject != null){
                if(name == 'Smooth Shading'){
                  _scene!.world.children[finalSelectedObject!].mesh.calculateVertexNormals(Shading.Smooth);
                }
                else{
                  _scene!.world.children[finalSelectedObject!].mesh.calculateVertexNormals(Shading.Flat);
                }
              }
            }
          }
        },
        child: Container(
          height: 25,
          width: 140,
          alignment: Alignment.center,
          padding: const EdgeInsets.fromLTRB(5,0,5,0),
          decoration: BoxDecoration(
            color: (clickedName == name)?Theme.of(context).accentColor:Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            boxShadow: [BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 5,
              offset: const Offset(0,2),
            ),]
          ),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          )
        )
      )
    );
  }
  Widget slider(){
    return Container(
      //padding: const EdgeInsets.only(left: 10,right: 10),
      margin: const EdgeInsets.all(5),
      height: 25,
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        boxShadow: [BoxShadow(
          color: Theme.of(context).shadowColor,
          blurRadius: 5,
          offset: const Offset(0,2),
        ),]
      ),
      child: Slider(
        value: illum.toDouble(),
        min: 0,
        max: 100,
        divisions: 25,
        label: illum.round().toString(),
        onChanged: (double value) {
          setState(() {
            if(finalSelectedObject != null){
              illum = value.toInt();
              changeObjectEmissivity();
            }
          });
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children:[ 
          Cube(
            onSceneCreated: _onSceneCreated,
            callback: cubeCallback,
          ),
          _scene != null?Align(
            alignment: Alignment.topRight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              slider(),
              objectButton('Change Color'),
              objectButton('Flat Shading'),
              objectButton('Smooth Shading'),
              objectButton('Remove Duplicates'),
              objectButton('Seperate By Loose Parts'),
              objectBox('Wireframe',_scene!.showWireframe),
              objectBox('Verticies',_scene!.showVerticies),
              objectBox('X-Ray',_scene!.xray),
              objectBox('Texture',_scene!.showTexture),
              Container(
                padding: const EdgeInsets.only(left: 10,right: 10),
                height: 25,
                width: 120,
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  boxShadow: [BoxShadow(
                    color: Theme.of(context).shadowColor,
                    blurRadius: 5,
                    offset: const Offset(0,2),
                  ),]
                ),
                child: Text(tappedObject != null?tappedObject!:'NONE')
              ),
            ],
          )):Container(),
      ])
    );
  }
}

Future<Color?> changeColor(BuildContext context, Color selectedColor ) async {
  return showDialog<Color>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      Color color = selectedColor;
      return AlertDialog(
        title: const Text('Pick a color!'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: (newColor){
              color = newColor;
            },
          ),
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Got it'),
            onPressed: () {
              Navigator.pop(context,color);
            },
          ),
        ],
      );
    }
  );
}
