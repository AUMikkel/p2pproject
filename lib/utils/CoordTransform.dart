import 'dart:math';
import 'package:latlong2/latlong.dart';

class CoordinateTransform {
  final LatLng referencePoint;

  CoordinateTransform(this.referencePoint);

  List<double> gpsToENU(LatLng point) {
    const double a = 6378137.0; // WGS-84 Earth semimajor axis (meters)
    const double f = 1.0 / 298.257223563; // WGS-84 flattening
    const double b = a * (1 - f); // Semi-minor axis

    double latRef = referencePoint.latitude * pi / 180.0;
    double lonRef = referencePoint.longitude * pi / 180.0;
    double lat = point.latitude * pi / 180.0;
    double lon = point.longitude * pi / 180.0;

    double sinLatRef = sin(latRef);
    double cosLatRef = cos(latRef);
    double sinLat = sin(lat);
    double cosLat = cos(lat);
    double cosLonDiff = cos(lon - lonRef);

    double e2 = 1 - (b * b) / (a * a);
    double N = a / sqrt(1 - e2 * sinLatRef * sinLatRef);

    double xRef = N * cosLatRef * cos(lonRef);
    double yRef = N * cosLatRef * sin(lonRef);
    double zRef = (b * b / (a * a) * N) * sinLatRef;

    double x = N * cosLat * cos(lon);
    double y = N * cosLat * sin(lon);
    double z = (b * b / (a * a) * N) * sinLat;

    double dx = x - xRef;
    double dy = y - yRef;
    double dz = z - zRef;

    double enuX = -sin(lonRef) * dx + cos(lonRef) * dy;
    double enuY = -sinLatRef * cos(lonRef) * dx - sinLatRef * sin(lonRef) * dy + cosLatRef * dz;
    double enuZ = cosLatRef * cos(lonRef) * dx + cosLatRef * sin(lonRef) * dy + sinLatRef * dz;

    return [enuX, enuY, enuZ];
  }

  List<double> transformIMUDataToENU(List<double> imuData, double roll, double pitch, double yaw) {
    List<List<double>> rollMatrix = [
      [1, 0, 0],
      [0, cos(roll), -sin(roll)],
      [0, sin(roll), cos(roll)]
    ];

    List<List<double>> pitchMatrix = [
      [cos(pitch), 0, sin(pitch)],
      [0, 1, 0],
      [-sin(pitch), 0, cos(pitch)]
    ];

    List<List<double>> yawMatrix = [
      [cos(yaw), -sin(yaw), 0],
      [sin(yaw), cos(yaw), 0],
      [0, 0, 1]
    ];

    List<List<double>> rotationMatrix = matrixMultiply(matrixMultiply(rollMatrix, pitchMatrix), yawMatrix);
    return matrixVectorMultiply(rotationMatrix, imuData);
  }

  List<List<double>> matrixMultiply(List<List<double>> A, List<List<double>> B) {
    int rowsA = A.length;
    int colsA = A[0].length;
    int colsB = B[0].length;
    List<List<double>> result = List.generate(rowsA, (_) => List.filled(colsB, 0.0));
    for (int i = 0; i < rowsA; i++) {
      for (int j = 0; j < colsB; j++) {
        for (int k = 0; k < colsA; k++) {
          result[i][j] += A[i][k] * B[k][j];
        }
      }
    }
    return result;
  }

  List<double> matrixVectorMultiply(List<List<double>> matrix, List<double> vector) {
    int rows = matrix.length;
    int cols = matrix[0].length;
    List<double> result = List.filled(rows, 0.0);
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[i] += matrix[i][j] * vector[j];
      }
    }
    return result;
  }
}