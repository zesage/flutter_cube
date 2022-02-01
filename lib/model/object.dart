import 'package:vector_math/vector_math_64.dart' hide Triangle;
import 'dart:ui';
import 'package:flutter_cube/scene/scene.dart';
import 'mesh.dart';
import 'package:flutter_cube/loader/loader.dart';

class Object {
  Object({
    Vector3? position,
    Vector3? rotation,
    Vector3? scale,
    this.name,
    Mesh? mesh,
    Scene? scene,
    this.parent,
    List<Object>? children,
    this.backfaceCulling = true,
    this.lighting = false,
    this.visiable = true,
    this.xray = false,
    this.showVerts = false,
    bool normalized = true,
    String? fileName,
    String? fileType,
    this.number,
    bool isAsset = true,
  }) {
    if (position != null) position.copyInto(this.position);
    if (rotation != null) rotation.copyInto(this.rotation);
    if (scale != null) scale.copyInto(this.scale);
    updateTransform();
    this.mesh = mesh ?? Mesh();
    this.children = children ?? <Object>[];
    for (Object child in this.children) {
      child.parent = this;
    }
    this.scene = scene;

    if(fileName != null && fileType == null)
      fileType = fileName.split('.')[1];
    // load mesh from obj file
    if (fileName != null && fileType != null) {
      if(fileType == 'obj')
        OBJLoader.load(fileName, normalized, isAsset: isAsset).then((List<Mesh> meshes) {
          if (meshes.length == 1) 
            this.mesh = meshes[0];
          else if (meshes.length > 1)
            for (Mesh mesh in meshes) 
              add(Object(name: mesh.name, mesh: mesh, backfaceCulling: backfaceCulling, lighting: lighting, number: number,showVerts: showVerts));
          this.scene?.objectCreated(this);
        });
      else if(fileType == 'stl')
        STLLoader.load(fileName, normalized, isAsset: isAsset).then((List<Mesh> meshes) {
          if (meshes.length == 1)
            this.mesh = meshes[0];
          else if (meshes.length > 1)
            for (Mesh mesh in meshes)
              add(Object(name: mesh.name, mesh: mesh, backfaceCulling: backfaceCulling, lighting: lighting, number: number,showVerts: showVerts));
          this.scene?.objectCreated(this);
        });
      else if(fileType == 'x3d')
        X3DLoader.load(fileName, normalized, isAsset: isAsset).then((List<Mesh> meshes) {
          if (meshes.length == 1)
            this.mesh = meshes[0];
          else if (meshes.length > 1)
            for (Mesh mesh in meshes)
              add(Object(name: mesh.name, mesh: mesh, backfaceCulling: backfaceCulling, lighting: lighting, number: number,showVerts: showVerts));
          this.scene?.objectCreated(this);
        });
      else if(fileType == 'ply')
        PLYLoader.load(fileName, normalized, isAsset: isAsset).then((List<Mesh> meshes) {
          if (meshes.length == 1)
            this.mesh = meshes[0];
          else if (meshes.length > 1)
            for (Mesh mesh in meshes)
              add(Object(name: mesh.name, mesh: mesh, backfaceCulling: backfaceCulling, lighting: lighting, number: number,showVerts: showVerts));
          this.scene?.objectCreated(this);
        });
    } 
    else {
      this.scene?.objectCreated(this);
    }
  }

  /// The local position of this object relative to the parent. Default is Vector3(0.0, 0.0, 0.0). updateTransform after you change the value.
  final Vector3 position = Vector3(0.0, 0.0, 0.0);

  /// The local rotation of this object relative to the parent. Default is Vector3(0.0, 0.0, 0.0). updateTransform after you change the value.
  final Vector3 rotation = Vector3(0.0, 0.0, 0.0);

  /// The local scale of this object relative to the parent. Default is Vector3(1.0, 1.0, 1.0). updateTransform after you change the value.
  final Vector3 scale = Vector3(1.0, 1.0, 1.0);

  /// The name of this object.
  String? name;

  int? number;

  /// The scene of this object.
  Scene? _scene;
  Scene? get scene => _scene;
  set scene(Scene? value) {
    _scene = value;
    for (Object child in children) {
      child.scene = value;
    }
  }

  /// The parent of this object.
  Object? parent;

  /// The children of this object.
  late List<Object> children;

  /// The mesh of this object
  Image? texture;

  /// The mesh of this object
  late Mesh mesh;

  /// The backface will be culled without rendering.
  bool backfaceCulling;

  /// Enable basic lighting, default to false.
  bool lighting;

  /// Is this object visiable.
  bool visiable;

  //See al point on object
  bool xray;

  //Show verticies
  bool showVerts;

  /// The transformation of the object in the scene, including position, rotation, and scaling.
  final Matrix4 transform = Matrix4.identity();

  void updateTransform() {
    final Matrix4 m = Matrix4.compose(position, Quaternion.euler(radians(rotation.x), radians(rotation.y),radians(rotation.z)), scale);//
    transform.setFrom(m);
  }

  List<Mesh> _getSeperatedMeshs(){
    List<Mesh> allMesh = [];
    List<Triangle> tempPoly =  mesh.indices;
    List<Triangle> tri =  [];
    List<Color> colors = [];
    List<Vector3> verts = [];
    List<Vector3> nors = [];
    List<Offset> text = [];

    List<int> tempIndi = [];

    int k = 0;

    while(tempPoly.isNotEmpty){
      void reset(){
        allMesh.add(
          Mesh(
            vertices: verts,
            normals: nors,
            texcoords: text,
            indices: tri,
            colors: colors,
            texture: mesh.texture,
            texturePath: mesh.texturePath,
            name: mesh.name,
          )
        );
        tri =  [];
        colors = [];
        verts = [];
        nors = [];
        text = [];
        tempIndi = [];
      }
      void addItems(int j){
        dynamic getVect<type>(dynamic verts, List<int> indi){
          dynamic newVerts = [];
          for(int i = 0; i < indi.length;i++){
            newVerts.add(verts[indi[i]]);
          }
          return newVerts;
        }
        getVect(mesh.vertices, tempPoly[j].vertexes).forEach((element) { 
          verts.add(element);
        });
        if(mesh.normals.isNotEmpty)
          getVect(mesh.normals, tempPoly[j].vertexes).forEach((element) { 
            nors.add(element);
          });
        if(mesh.texcoords.isNotEmpty)
          getVect(mesh.texcoords, tempPoly[j].vertexes).forEach((element) { 
            text.add(element);
          });
        if(mesh.colors.isNotEmpty)
          getVect(mesh.colors, tempPoly[j].vertexes).forEach((element) { 
            colors.add(element);
          });
        tri.add(Triangle(
          [verts.length-3,verts.length-2,verts.length-1], 
          (nors.isNotEmpty)?[nors.length-3,nors.length-2,nors.length-1]:null, 
          (text.isNotEmpty)?[text.length-3,text.length-2,text.length-1]:null
        ));
        tempPoly[j].vertexes.forEach((element) { 
          tempIndi.add(element);
        });

        if(tempPoly.length == 1)
          reset();
        tempPoly.removeAt(j);
        k = 0;
      }
      bool checkforsamevertexes(Triangle tempPoly1){
        for(int l = 0; l < tempIndi.length; l++){
          for(int k = 0; k < tempPoly1.vertexes.length; k++){
            if(tempPoly1.vertexes[k] == tempIndi[l]){
              k = 0;
              return true;
            }
          }
        }
        return false;
      }
      
      if(tri.isEmpty){
        addItems(0);
        tempPoly[0].vertexes.forEach((element) { 
          tempIndi.add(element);
        });
      }

      for(int j = tempPoly.length-1; j >= 0; j--){
        if(checkforsamevertexes(tempPoly[j]))
          addItems(j);
      }

      if(k > 2){
        reset();
      }
      k++;
    }

    return allMesh;
  }
  void seperateByLooseParts(){
    List<Mesh> newMeshes = _getSeperatedMeshs();

    for(int i = 0; i < newMeshes.length;i++){
      add(
        Object(
          name: name!.split('_')[0]+'_'+i.toString(), 
          mesh: newMeshes[i], 
          backfaceCulling: backfaceCulling, 
          lighting: lighting, 
          number: number,
          showVerts: showVerts
        )
      );
    }

    name = name!.split('_')[0];
    mesh = Mesh();
  }

  /// Add a child
  void add(Object object) {
    assert(object != this);
    object.scene = scene;
    object.parent = this;
    children.add(object);
  }

  /// Remove a child
  void remove(Object object) {
    children.remove(object);
  }

  /// Find a child matching the name
  Object? find(Pattern name) {
    for (Object child in children) {
      if (child.name != null && (name as RegExp).hasMatch(child.name!)) return child;
      final Object? result = child.find(name);
      if (result != null) return result;
    }
    return null;
  }
}
