import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_cube/flutter_cube.dart';

class SVGExporter{
  static Future<String> export(Scene scene) async {
    // create render mesh from objects
    final renderMesh = scene.makeRenderMesh();
    final List<Triangle?> renderPolys = scene.renderObject(renderMesh, scene.world, Matrix4.identity(), scene.camera.lookAtMatrix, scene.camera.projectionMatrix, false);
    final int indexCount = renderPolys.length;
    final Uint16List indices = Uint16List(indexCount * 3);

    renderPolys.sort((Triangle? a, Triangle? b){
      return scene.paintersAlgorithm(a,b);
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

    return svgStacked(renderMesh,indices);
  }

  static String svgStacked(RenderMesh renderMesh, Uint16List indices){
    String top = '<svg viewBox="0 100 xx2 yy2" version="1.1" xmlns="http://www.w3.org/2000/svg" style="background-color: rgba(255, 255, 255,0.0);"><style type="text/css">.st{stroke:#333333; stroke-width:1;}';
    String file = '</style>';
    String st = '';
    List<int> usedColors = []; 
    List<Vector2> values = [Vector2(0,0),Vector2(0,0)];

    checkValues(Vector2 val){
      if(val.x < values[0].x)
        values[0].x = val.x;
      if(val.x > values[1].x)
        values[1].x = val.x;
      if(val.y < values[0].y)
        values[0].y = val.y;
      if(val.y > values[1].y)
        values[1].y = val.y;
    }

    int colorCheck(int color){
      bool isColorUsed = false;
      int newColorLoc = 0;
      for(int i = 0; i < usedColors.length; i++){
        if(usedColors[i] == color){
          newColorLoc = i;
          isColorUsed = true;
          break;
        }
      }

      if(!isColorUsed){
        usedColors.add(color);
        newColorLoc = usedColors.length-1;
        int actColor = 0xFFFFFF & Color(color).value;
        String hexString ='#${actColor.toRadixString(16).padLeft(6, '0')}';
        print(hexString);
        st += '.st'+newColorLoc.toString()+'{fill:'+hexString+';}';
      }
      return newColorLoc;
    }
    int colorLoc = 0;
    for(int i = 0; i < indices.length; i=i+3){
      if(i != 0){
        file += '" class="st'+colorLoc.toString()+' st"></path>';
      }
      file += '<path d="';

      final Float32List temp = Float32List(6);
      temp[0] = renderMesh.positions[indices[i]*2];
      temp[1] = renderMesh.positions[indices[i]*2+1];
      temp[2] = renderMesh.positions[indices[i+1]*2];
      temp[3] = renderMesh.positions[indices[i+1]*2+1];
      temp[4] = renderMesh.positions[indices[i+2]*2];
      temp[5] = renderMesh.positions[indices[i+2]*2+1];

      checkValues(Vector2(temp[0],temp[1]));
      checkValues(Vector2(temp[2],temp[3]));
      checkValues(Vector2(temp[4],temp[5]));

      file += 'M'+temp[0].toStringAsFixed(2)+','+temp[1].toStringAsFixed(2);
      file += 'L'+temp[2].toStringAsFixed(2)+','+temp[3].toStringAsFixed(2);
      file += 'L'+temp[4].toStringAsFixed(2)+','+temp[5].toStringAsFixed(2)+'z';
      colorLoc = colorCheck(renderMesh.colors[indices[i]]);
    }
    file += '" class="st'+colorLoc.toString()+' st"></path>';
    file += '</svg>';

    top = top.replaceAll('xx2', (values[1].x*2).ceil().toString());
    top = top.replaceAll('yy2', values[1].y.ceil().toString());

    return top+st+file;
  }
}