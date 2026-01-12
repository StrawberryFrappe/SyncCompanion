import 'dart:io';
import 'dart:math' as math;

/// Utility class to generate a Torus (Donut) mesh as an OBJ file.
class DonutMesh {
  /// R = Major Radius (Distance from center of hole to center of tube)
  final double majorRadius;
  
  /// r = Minor Radius (Thickness of the tube)
  final double minorRadius;
  
  /// Resolution around the ring
  final int uSteps;
  
  /// Resolution around the tube
  final int vSteps;

  DonutMesh({
    required this.majorRadius,
    required this.minorRadius,
    this.uSteps = 50,
    this.vSteps = 30,
  });

  /// Generates an OBJ file at the given path and returns the file.
  Future<File> generateObjFile(String path) async {
    final file = File(path);
    final buffer = StringBuffer();
    buffer.writeln('o Donut');
    
    final double R = majorRadius; 
    final double r = minorRadius; 
    
    // Generate Vertices & Normals
    for (int u = 0; u < uSteps; u++) {
      double theta = (u / uSteps) * 2 * math.pi;
      double cosTheta = math.cos(theta);
      double sinTheta = math.sin(theta);
      
      for (int v = 0; v < vSteps; v++) {
        double phi = (v / vSteps) * 2 * math.pi;
        double cosPhi = math.cos(phi);
        double sinPhi = math.sin(phi);
        
        double x = (R + r * cosPhi) * cosTheta;
        double y = r * sinPhi;
        double z = (R + r * cosPhi) * sinTheta;
        
        buffer.writeln('v $x $y $z');
        
        double nx = cosPhi * cosTheta;
        double ny = sinPhi;
        double nz = cosPhi * sinTheta;
        buffer.writeln('vn $nx $ny $nz');
      }
    }
    
    // Generate Faces - Side A (Red) - Top Half
    buffer.writeln('usemtl SideA');
    for (int u = 0; u < uSteps; u++) {
      for (int v = 0; v < vSteps / 2; v++) {
        _writeFace(buffer, u, v);
      }
    }

    // Side B (Blue) - Bottom Half
    buffer.writeln('usemtl SideB');
    for (int u = 0; u < uSteps; u++) {
      for (int v = vSteps ~/ 2; v < vSteps; v++) {
        _writeFace(buffer, u, v);
      }
    }
    
    await file.writeAsString(buffer.toString());
    return file;
  }

  void _writeFace(StringBuffer buffer, int u, int v) {
    int nextU = (u + 1) % uSteps;
    int nextV = (v + 1) % vSteps;
    
    int p1 = u * vSteps + v + 1;
    int p2 = nextU * vSteps + v + 1;
    int p3 = nextU * vSteps + nextV + 1;
    int p4 = u * vSteps + nextV + 1;
    
    buffer.writeln('f $p1//$p1 $p2//$p2 $p3//$p3 $p4//$p4');
  }
}
