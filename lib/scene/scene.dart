import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_cube/flutter_cube.dart';
import 'package:flutter_cube/scene/light.dart';

enum RenderType{Wireframe,Normal}
enum SortingType{Painters,HSR}

typedef ObjectCreatedCallback = void Function(Object object);

class Scene {
  Scene({
    VoidCallback? onUpdate, 
    ObjectCreatedCallback? onObjectCreated,
  }) {
    this._onUpdate = onUpdate;
    this._onObjectCreated = onObjectCreated;
    world = Object(scene: this);
  }

  Light light = Light();
  Camera camera = Camera();
  late Object world;
  /// allows tapping and hovering on objects
  bool rayCasting = false;
  Image? texture;
  BlendMode blendMode = BlendMode.srcOver;
  /// Blend mode of texture image, change this to colorDodge if there is only a normal map to allow changing colors.
  BlendMode textureBlendMode = BlendMode.srcOver;
  VoidCallback? _onUpdate;
  /// Location of the tapped spot
  Offset? tapLocation;
  /// Location where the mouse is hovering
  Offset? hoverLocation;
  ObjectCreatedCallback? _onObjectCreated;
  int vertexCount = 0;
  int faceCount = 0;
  int polyCount = 0;
  /// name of the object tapped on
  String? _objectTappedOn;
  String? _prevObjectTappedOn;
  /// name of the object hovering on
  String? _objectHoveringOn;
  double? _currentSum;
  double? _currentHoverSum;
  bool _needsUpdateTexture = false;

  /// Turn on wreframe
  bool showWireframe = false;
  /// Turn on verticies
  bool showVerticies = false;
  /// show through model
  bool xray = false;
  /// show Texture
  bool showTexture = true;

  SortingType sortingType = SortingType.HSR;

  // calcuthe total number of vertices and facese
  void _calculateVertices(Object o) {
    vertexCount += o.mesh.vertices.length*(showVerticies?2:1);
    faceCount += o.mesh.indices.length*(showWireframe?3:1);
    final List<Object> children = o.children;
    for (int i = 0; i < children.length; i++)
      _calculateVertices(children[i]);
  }
  /// returns the name of the object tapped on
  String? clickedObject(){
    _prevObjectTappedOn = _objectTappedOn;
    tapLocation = null;
    _currentSum = null;

    return _prevObjectTappedOn;
  }
  /// returns the name of the object hovered on
  String? hoverObject(){
    _currentHoverSum = null;
    return _objectHoveringOn;
  }
  
  RenderMesh makeRenderMesh(){
    vertexCount = 0;
    faceCount = 0;
    polyCount = 0;
    _calculateVertices(world);
    final renderMesh = RenderMesh(vertexCount, faceCount);
    renderMesh.texture = texture;
    return renderMesh;
  }

  bool _isFrontFace(List<double> x, List<double> y, List<double> z) {
    Vector3 P1 = Vector3(x[0],y[0],z[0]);
    Vector3 P2 = Vector3(x[1],y[1],z[1]);
    Vector3 P3 = Vector3(x[2],y[2],z[2]);

    Vector3 V = P2-P1;
    Vector3 W = P3-P1;

    Vector3 N = Vector3(
      ((V.y*W.z)-(V.z*W.y)),
      ((V.z*W.x)-(V.x*W.z)),
      ((V.x*W.y)-(V.y*W.x))
    )..normalize();
    Vector3 centroid = Vector3((x[0]+x[1]+x[2])/3,(y[0]+y[1]+y[2])/3,(z[0]+z[1]+z[2])/3)..normalize();
    double dot = centroid.dot(N);
    return dot < 0;
  }
  bool _isClippedFace(List<double> x, List<double> y, List<double> z) {
    // clip if at least one vertex is outside the near and far plane
    if (z[0] < 0 || z[0] > 1 || z[1] < 0 || z[1] > 1 || z[2] < 0 || z[2] > 1) return true;
    // clip if the face's bounding box does not intersect the viewport
    double left;
    double right;
    if (x[0] < x[1]) {
      left = x[0];
      right = x[1];
    } 
    else {
      left = x[1];
      right = x[0];
    }
    if (left > x[2]) left = x[2];
    if (left > 1) return true;
    if (right < x[2]) right = x[2];
    if (right < -1) return true;
    
    double top;
    double bottom;
    if (y[0] < y[1]) {
      top = y[0];
      bottom = y[1];
    } 
    else {
      top = y[1];
      bottom = y[0];
    }
    if (top > y[2]) top = y[2];
    if (top > 1) return true;
    if (bottom < y[2]) bottom = y[2];
    if (bottom < -1) return true;
    return false;
  }
  //this is for checking what item has been tapped on
  bool _isBelow(Offset p,List<double> x, List<double> y,Offset v){
    double sign (double hx, double hy, double ix, double iy, double kx, double ky){
      return (hx - kx) * (iy - ky) - (ix - kx) * (hy - ky);
    }
    double d1, d2, d3;
    bool hasNeg, hasPos;

    d1 = sign(p.dx, p.dy ,((1.0+x[0])*v.dx/2), ((1.0-y[0])*v.dy/2), ((1.0+x[1])*v.dx/2), ((1.0-y[1])*v.dy/2));
    d2 = sign(p.dx, p.dy, ((1.0+x[1])*v.dx/2), ((1.0-y[1])*v.dy/2), ((1.0+x[2])*v.dx/2), ((1.0-y[2])*v.dy/2));
    d3 = sign(p.dx, p.dy, ((1.0+x[2])*v.dx/2), ((1.0-y[2])*v.dy/2), ((1.0+x[0])*v.dx/2), ((1.0-y[0])*v.dy/2));

    hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);

    return !(hasNeg && hasPos);
  }
  //painters algorithm sorts triangles that are in the top most z positions
  int paintersAlgorithm(Triangle? a, Triangle? b){
    //return b.sumOfZ.compareTo(a.sumOfZ);
    if(a == null) return -1;
    if(b == null) return -1;
    final double az = a.z;
    final double bz = b.z;
    //return (az-bz).round();
    if (bz > az) return 1;
    if (bz < az) return -1;
    return 0;
  }

  Float64List storage(Vector3 vertices, Matrix4 transform){
    final Vector4 v = Vector4.identity();
    // Conver Vector3 to Vector4
    final Float64List storage3 = vertices.storage;
    v.setValues(storage3[0], storage3[1], storage3[2], 1.0);
    // apply "model => world => camera => perspective" transform
    v.applyMatrix4(transform);
    // transform from homonegenous coordinates to the normalized device coordinates，
    return v.storage;
  }

  List<Triangle> renderObject(RenderMesh renderMesh, Object o, Matrix4 model, Matrix4 view, Matrix4 projection,[bool lightOn = true]) {
    if (!o.visiable) return [];
    model *= o.transform;
    List<Triangle> triangles = [];
    final Matrix4 transform = projection*view*model;

    // apply transform and add vertices to renderMesh
    final double viewportWidth = camera.viewportWidth;
    final double viewportHeight = camera.viewportHeight;
    final Offset viewport = Offset(viewportWidth,viewportHeight);

    final Float32List positions = renderMesh.positions;
    final Float32List positionsZ = renderMesh.positionsZ;

    final List<Vector3> vertices = o.mesh.vertices;
    final List<Vector3> normals = o.mesh.normals;

    final int vertexOffset = renderMesh.vertexCount;
    final int vertexCount = vertices.length;
    
    renderMesh.vertexCount += vertexCount;

    // add faces to renderMesh
    final List<Triangle?> renderIndices = renderMesh.indices;
    final List<Triangle> indices = o.mesh.indices;
    final int indexOffset = renderMesh.indexCount;
    final int indexCount = indices.length;
    final bool culling = o.backfaceCulling;

    //color information
    final Int32List renderColors = renderMesh.colors;
    final Matrix4 normalTransform = (model.clone()..invert()).transposed();
    final Vector3 viewPosition = camera.position;
    final Material material = o.mesh.material;
    final List<Color> colors = o.mesh.colors;
    final int colorValue = (o.mesh.texture != null) ? Color.fromARGB(0, 0, 0, 0).value : toColor(o.mesh.material.diffuse, o.mesh.material.opacity).value;

    //texture information
    final Float32List renderTexcoords = renderMesh.texcoords;
    final int? imageWidth = o.mesh.texture == null?null:o.mesh.textureRect.width.toInt();
    final int? imageHeight = o.mesh.texture == null?null:o.mesh.textureRect.height.toInt();
    final double? imageLeft = o.mesh.texture == null?null:o.mesh.textureRect.left;
    final double? imageTop = o.mesh.texture == null?null:o.mesh.textureRect.top;
    final List<Offset>? texcoords = o.mesh.texture == null?null:o.mesh.texcoords;

    for (int i = 0; i < indexCount; i++){
      final Triangle p = indices[i];
      List<int> vertexes = [];
      List<double> x = [];
      List<double> y = [];
      List<double> z = [];

      List<double> xp = [];
      List<double> yp = [];

      double sumOfZ = 0;

      for(int j = 0; j < p.vertexes.length;j++){
        final vertex = vertexOffset + p.vertexes[j];
        vertexes.add(vertex);
        
        Float64List storage4 = storage(vertices[p.vertexes[j]], transform);
        double w = storage4.length > 3?storage4[3]:1.0;
        double posx =  storage4.length > 3?storage4[0]/w:storage4[0]/(viewportWidth / 2)-1.0;
        double posy =  storage4.length > 3?storage4[1]/w:-(storage4[1]/(viewportHeight / 2)-1.0);
        positionsZ[vertex] = storage4.length > 3?storage4[2]/w:storage4[2]/(camera.far/2)+0.1;
        x.add(posx);
        y.add(posy);
        z.add(positionsZ[vertex]);
        positions[vertex * 2] = storage4.length > 3?((1.0 + posx) * viewportWidth / 2):storage4[0];
        positions[vertex * 2 + 1] = storage4.length > 3?((1.0 - posy) * viewportHeight / 2):storage4[1];
        xp.add(positions[vertex * 2]);
        yp.add(positions[vertex * 2+1]);
        sumOfZ += positionsZ[vertex];

        if(o.lighting && lightOn){
          final Vector3 a = Vector3.zero();
          final Vector3 an = Vector3.zero();

          a.setFrom(vertices[p.vertexes[j]]);

          final Vector3 normal = a
            ..applyMatrix4(normalTransform)
            ..normalize();

          if(normals.isNotEmpty)
            an
            ..setFrom(normals[p.normals![j]])
            ..applyMatrix4(normalTransform)
            ..normalize();
          else
            an.setFrom(normal);
          
          a..applyMatrix4(normalTransform);
          Color color = light.shading(viewPosition, a, an, material);
          renderColors[vertex] = color.value;
        } 
        else {
          if (vertexCount != o.mesh.colors.length)
            renderColors[vertex] = colorValue;
          else 
            renderColors[vertex] = colors[i].value;
        }

        if (o.mesh.texture != null && o.mesh.texcoords.length == vertexCount && showTexture) {
          final Offset t = texcoords![p.texture![j]];
          final double x = t.dx * imageWidth! + imageLeft!;
          final double y = (1.0 - t.dy) * imageHeight! + imageTop!;
          renderTexcoords[vertex * 2] = x;
          renderTexcoords[vertex * 2 + 1] = y;
        } 
        else {
          renderTexcoords[vertex * 2] = 0;
          renderTexcoords[vertex * 2 + 1] = 0;
        }
      }

      final bool isFF = !_isFrontFace(x,y,z);

      if(!culling || isFF || xray){
        bool showFace = false;
        if(xray || o.xray || (showWireframe || showVerticies) && isFF)
          showFace = true;
        if (!_isClippedFace(x,y,z)) {
          double zHeight = sumOfZ;
          renderIndices[indexOffset + i] = Triangle(vertexes,null,null,zHeight,showFace);
          triangles.add(renderIndices[indexOffset + i]!);
          if(tapLocation != null && _isBelow(tapLocation!,x,y,viewport)){
            if(_currentSum == null){
              _currentSum = sumOfZ;
              _objectTappedOn = o.name;
            }
            else if(_currentSum! > sumOfZ){
              _currentSum = sumOfZ;
              _objectTappedOn = o.name;
            }
          }
          if(hoverLocation != null && _isBelow(hoverLocation!,x,y,viewport)){
            if(_currentHoverSum == null){
              _currentHoverSum = sumOfZ;
              _objectHoveringOn = o.name;
            }
            else if(_currentHoverSum! > sumOfZ){
              _currentHoverSum = sumOfZ;
              _objectHoveringOn = o.name;
            }
          }
        }
      }
    }
    renderMesh.indexCount += indexCount;

    // render children
    List<Object> children = o.children;
    for (int i = 0; i < children.length; i++)
      triangles += renderObject(renderMesh, children[i], model, view, projection, lightOn);

    return triangles;
  } 
  void render(Canvas canvas, Size size) {
    _objectHoveringOn = null;
    // check if texture needs to update
    if (_needsUpdateTexture){
      _needsUpdateTexture = false;
      _updateTexture();
    }
    // create render mesh from objects
    final renderMesh = makeRenderMesh();
    final List<Triangle?> renderPolys = renderObject(renderMesh, world, Matrix4.identity(), camera.lookAtMatrix, camera.projectionMatrix);
    final int indexCount = renderPolys.length;
    final Uint16List indices = Uint16List(indexCount * 3);

    renderPolys.sort((Triangle? a, Triangle? b){
      return paintersAlgorithm(a,b);
    });

    for (int i = 0; i < indexCount; i++) {
      if(renderPolys[i] != null){
        final int index0 = i * 3;
        final int index1 = index0 + 1;
        final int index2 = index0 + 2;
        final Triangle triangle = renderPolys[i]!;

        indices[index0] = triangle.vertexes[0];
        indices[index1] = triangle.vertexes[1];
        indices[index2] = triangle.vertexes[2];
      }
    }

    if((!showVerticies && !showWireframe) || xray){
      _drwaVert(
        canvas, 
        renderMesh.positions, 
        renderMesh.texcoords,
        renderMesh.colors, 
        indices,
        renderMesh.texture
      );
    }
    if(showVerticies || showWireframe){
      int k =0 ;
      for (int j = 0; j < indices.length; j=j+3) {
        final Float32List temp = Float32List(6);
        temp[0] = renderMesh.positions[indices[j]*2];
        temp[1] = renderMesh.positions[indices[j]*2+1];
        temp[2] = renderMesh.positions[indices[j+1]*2];
        temp[3] = renderMesh.positions[indices[j+1]*2+1];
        temp[4] = renderMesh.positions[indices[j+2]*2];
        temp[5] = renderMesh.positions[indices[j+2]*2+1];

        if(!xray){
          final Float32List? tex = (renderMesh.texture == null)?null:Float32List(6);
          final Int32List colors = Int32List(3);
          colors[0] = renderMesh.colors[indices[j]];
          colors[1] = renderMesh.colors[indices[j+1]];
          colors[2] = renderMesh.colors[indices[j+2]];

          if(renderMesh.texture != null){
            tex![0] = renderMesh.texcoords[indices[j]*2];
            tex[1] = renderMesh.texcoords[indices[j]*2+1];
            tex[2] = renderMesh.texcoords[indices[j+1]*2];
            tex[3] = renderMesh.texcoords[indices[j+1]*2+1];
            tex[4] = renderMesh.texcoords[indices[j+2]*2];
            tex[5] = renderMesh.texcoords[indices[j+2]*2+1];
          }
          _drwaVert(
            canvas, 
            temp, 
            tex,
            colors, 
            null, 
            renderMesh.texture
          );
        }
        if(showWireframe){
          final Paint paint = new Paint()      
          ..isAntiAlias = true
          ..color = Color(0xff000000)
          ..style = PaintingStyle.fill
          ..strokeWidth = 0.5
          ..blendMode = blendMode;

          final Float32List temp2 = Float32List(8);

          temp2[0] = renderMesh.positions[indices[j]*2];
          temp2[1] = renderMesh.positions[indices[j]*2+1];
          temp2[2] = renderMesh.positions[indices[j+1]*2];
          temp2[3] = renderMesh.positions[indices[j+1]*2+1];
          temp2[4] = renderMesh.positions[indices[j+2]*2];
          temp2[5] = renderMesh.positions[indices[j+2]*2+1];
          temp2[6] = renderMesh.positions[indices[j]*2];
          temp2[7] = renderMesh.positions[indices[j]*2+1];

          canvas.drawRawPoints(PointMode.polygon, temp2, paint);
        }
        if(showVerticies){
          final Paint paint = new Paint()      
          ..isAntiAlias = true
          ..color = Color(0xffed9121)
          ..style = PaintingStyle.fill
          ..strokeWidth = 3
          ..blendMode = blendMode;

          canvas.drawRawPoints(PointMode.points, temp, paint);
        }
        k++;
      }
    }
  }

  void _drwaVert(Canvas canvas, Float32List positions, Float32List? texCoord,Int32List colors, Uint16List? indices, Image? texture){
    final vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      textureCoordinates: texCoord,
      colors: colors,
      indices: indices,
    );

    final paint = Paint()
    ..blendMode = xray?BlendMode.screen:blendMode;
    
    if (texture != null && showTexture) {
      final matrix4 = Matrix4.identity();
      final shader = ImageShader(texture, TileMode.clamp, TileMode.clamp, matrix4.storage, filterQuality: FilterQuality.high);
      paint.shader = shader;
    }
    
    canvas.drawVertices(vertices, xray?BlendMode.modulate:textureBlendMode, paint);
  }
  void objectCreated(Object object) {
    updateTexture();
    if (_onObjectCreated != null) _onObjectCreated!(object);
  }
  void update() {
    if (_onUpdate != null) _onUpdate!();
  }
  void _getAllMesh(List<Mesh> meshes, Object object) {
    meshes.add(object.mesh);
    final List<Object> children = object.children;
    for (int i = 0; i < children.length; i++) {
      _getAllMesh(meshes, children[i]);
    }
  }
  /// Mark needs update texture
  void _updateTexture() async {
    final meshes = <Mesh>[];
    _getAllMesh(meshes, world);
    texture = await packingTexture(meshes);
    update();
  }
  /// Mark update tap loaction
  void updateTapLocation(Offset details) {
    _objectTappedOn = null;
    tapLocation = details;
    update();
  }
  /// Mark update hover loaction
  void updateHoverLocation(Offset details) {
    hoverLocation = details;
    update();
  }
  /// Mark needs update texture
  void updateTexture() {
    _needsUpdateTexture = true;
    update();
  }
  Future<Image> generateImage(Size size) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0,0,size.width, size.height)
    );
    // create render mesh from objects
    final renderMesh = makeRenderMesh();
    final List<Triangle?> renderPolys = renderObject(renderMesh, world, Matrix4.identity(), camera.lookAtMatrix, camera.projectionMatrix);
    final int indexCount = renderPolys.length;
    final Uint16List indices = Uint16List(indexCount * 3);

    renderPolys.sort((Triangle? a, Triangle? b){
      return paintersAlgorithm(a,b);
    });

    for (int i = 0; i < indexCount; i++) {
      if(renderPolys[i] != null){
        final int index0 = i * 3;
        final int index1 = index0 + 1;
        final int index2 = index0 + 2;
        final Triangle triangle = renderPolys[i]!;

        indices[index0] = triangle.vertexes[0];
        indices[index1] = triangle.vertexes[1];
        indices[index2] = triangle.vertexes[2];
      }
    }
    _drwaVert(
      canvas, 
      renderMesh.positions, 
      renderMesh.texcoords,
      renderMesh.colors, 
      indices,
      renderMesh.texture
    );
    return await recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
  }
}

class RenderMesh {
  RenderMesh(int vertexCount, int faceCount) {
    positions = Float32List(vertexCount * 2);
    positionsZ = Float32List(vertexCount);
    texcoords = Float32List(vertexCount * 2);
    colors = Int32List(vertexCount);
    indices = List<Triangle?>.filled(faceCount, null);
  }
  late Float32List positions;
  late Float32List positionsZ;
  late Float32List texcoords;
  late Int32List colors;
  late List<Triangle?> indices;
  Image? texture;
  int vertexCount = 0;
  int indexCount = 0;
}
