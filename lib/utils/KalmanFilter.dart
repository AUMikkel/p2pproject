import 'dart:convert';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart';
import '../utils/CoordTransform.dart';

class KalmanFilter {
  final LatLng _referencePoint;

  // State vector [x, y, vx, vy]
  List<double> _state = [0.0, 0.0, 0.0, 0.0];
  // State covariance matrix P
  List<List<double>> _P = List.generate(4, (_) => List.filled(4, 0.0));
  // Process noise covariance matrix Q
  List<List<double>> _Q = List.generate(4, (_) => List.filled(4, 0.0));
  // Measurement noise covariance matrix R
  List<List<double>> _R = List.generate(4, (_) => List.filled(4, 0.0));
  // State transition matrix F
  List<List<double>> _F = List.generate(4, (_) => List.filled(4, 0.0));
  // Control input matrix G
  List<List<double>> _G = List.generate(4, (_) => List.filled(2, 0.0));
  // Measurement matrix H
  List<List<double>> _H = List.generate(4, (_) => List.filled(4, 0.0));


  KalmanFilter(this._referencePoint) {
    double accelerometerRMSNoise = 100 * 1e-6 * 9.81; // Convert 100 µg/√Hz to m/s²
    double sensorVariance = accelerometerRMSNoise * accelerometerRMSNoise; // Sensor variance
    double processVariance = 0.01; // Process variance

    // Initialize matrices
    for (int i = 0; i < 4; i++) {
      _P[i][i] = 1.0; // Initialized with 1.0 on the diagonal. Represents the initial uncertainty in the state estimate. A value of 1.0 indicates that we start with a moderate level of uncertainty.
      _Q[i][i] = processVariance; // Initialized with 0.1 on the diagonal. Represents the uncertainty in the process model. A value of 0.1 indicates a small amount of process noise.
      //_R[i][i] = 0.1; // Initialized with 0.1 on the diagonal. Represents the uncertainty in the sensor measurements. A value of 0.1 indicates a small amount of measurement noise.
      _H[i][i] = 1.0; // Initialized with 1.0 on the diagonal. Maps the state vector to the measurement vector. A value of 1.0 indicates a direct mapping between the state and the measurements.
    }

    // Initialized with accelerometerNoise^2 on the diagonal.
    // Represents the uncertainty in the sensor measurements.
    // A value of 0.1 indicates a small amount of measurement noise.
    // Update the measurement noise covariance matrix R
    _R[0][0] = sensorVariance; // x position noise
    _R[1][1] = sensorVariance; // y position noise
    _R[2][2] = sensorVariance; // x velocity noise
    _R[3][3] = sensorVariance; // y velocity noise
  }

  void reset() {
    _state = [0.0, 0.0, 0.0, 0.0];
    _P = List.generate(4, (_) => List.filled(4, 0.0));
    _Q = List.generate(4, (_) => List.filled(4, 0.0));
    _R = List.generate(4, (_) => List.filled(4, 0.0));
    _F = List.generate(4, (_) => List.filled(4, 0.0));
    _G = List.generate(4, (_) => List.filled(2, 0.0));
    _H = List.generate(4, (_) => List.filled(4, 0.0));
  }

  void reinitialize() {
    double accelerometerRMSNoise = 100 * 1e-6 * 9.81; // Convert 100 µg/√Hz to m/s²
    double sensorVariance = accelerometerRMSNoise * accelerometerRMSNoise; // Sensor variance
    double processVariance = 0.01; // Process variance

    // Initialize matrices
    for (int i = 0; i < 4; i++) {
      _P[i][i] = 1.0; // Initialized with 1.0 on the diagonal. Represents the initial uncertainty in the state estimate. A value of 1.0 indicates that we start with a moderate level of uncertainty.
      _Q[i][i] = processVariance; // Initialized with 0.1 on the diagonal. Represents the uncertainty in the process model. A value of 0.1 indicates a small amount of process noise.
      //_R[i][i] = 0.1; // Initialized with 0.1 on the diagonal. Represents the uncertainty in the sensor measurements. A value of 0.1 indicates a small amount of measurement noise.
      _H[i][i] = 1.0; // Initialized with 1.0 on the diagonal. Maps the state vector to the measurement vector. A value of 1.0 indicates a direct mapping between the state and the measurements.
    }

    // Initialized with accelerometerNoise^2 on the diagonal.
    // Represents the uncertainty in the sensor measurements.
    // A value of 0.1 indicates a small amount of measurement noise.
    // Update the measurement noise covariance matrix R
    _R[0][0] = sensorVariance; // x position noise
    _R[1][1] = sensorVariance; // y position noise
    _R[2][2] = sensorVariance; // x velocity noise
    _R[3][3] = sensorVariance; // y velocity noise
  }

  void predict(List<double> imuData, double dt) {
    print('Predicting state with IMU data: $imuData');
    print('Time step: $dt');
    // Update state transition matrix F
    _F[0][0] = 1.0;
    _F[0][2] = dt;
    _F[1][1] = 1.0;
    _F[1][3] = dt;
    _F[2][2] = 1.0;
    _F[3][3] = 1.0;

    // Update control input matrix G
    _G[0][0] = 0.5 * dt * dt;
    _G[1][1] = 0.5 * dt * dt;
    _G[2][0] = dt;
    _G[3][1] = dt;

    print('State transition matrix F: $_F');
    print('Control input matrix G: $_G');

    // Control input vector u (IMU acceleration data)
    List<double> u = imuData.sublist(0, 2); // [ax, ay]

    // Predict state: x_{k+1} = F x_k + G u_k
    List<double> statePred = List.filled(4, 0.0);
    for (int i = 0; i < 4; i++) {
      statePred[i] = 0.0;
      for (int j = 0; j < 4; j++) {
        statePred[i] += _F[i][j] * _state[j];
      }
      for (int j = 0; j < 2; j++) {
        statePred[i] += _G[i][j] * u[j];
      }
    }

    _state = statePred; //_applyThreshold(statePred);

    // Predict covariance: P_{k|k-1} = F P_{k-1|k-1} F^T + Q
    List<List<double>> Ft = _transpose(_F);
    _P = _matrixAdd(_matrixMultiply(_F, _matrixMultiply(_P, Ft)), _Q);
  }

  void update(List<double> gpsData) {
    print("Before update - State: $_state");
    print("GPS Data: $gpsData");
    // Measurement residual: y_k = z_k - H x_{k|k-1}
    List<double> y = List.filled(4, 0.0);
    for (int i = 0; i < 4; i++) {
      y[i] = gpsData[i];
      for (int j = 0; j < 4; j++) {
        y[i] -= _H[i][j] * _state[j];
      }
    }

    // Kalman gain: K_k = P_{k|k-1} H^T S_k^{-1}
    List<List<double>> Ht = _transpose(_H);
    List<List<double>> S = _matrixAdd(_matrixMultiply(_H, _matrixMultiply(_P, Ht)), _R);
    List<List<double>>? inverseS = _inverse(S);
    List<List<double>> K;
    if (inverseS != null) {
      K = _matrixMultiply(_P, _matrixMultiply(Ht, inverseS));
    } else {
      K = _matrixMultiply(_P, _matrixMultiply(Ht, _pseudoinverse(S)));
    }

    // Update state: x_{k|k} = x_{k|k-1} + K_k y_k
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        _state[i] += K[i][j] * y[j];
      }
    }

    _state = _state; //_applyThreshold(_state);

    // Update covariance: P_{k|k} = (I - K_k H) P_{k|k-1}
    List<List<double>> I = _identityMatrix(4);
    _P = _matrixMultiply(_matrixSubtract(I, _matrixMultiply(K, _H)), _P);
    print("After update - Updated State: $_state");
  }

  // Helper functions for matrix operations
  List<List<double>> _transpose(List<List<double>> matrix) {
    int rows = matrix.length;
    int cols = matrix[0].length;
    List<List<double>> result = List.generate(cols, (_) => List.filled(rows, 0.0));
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[j][i] = matrix[i][j];
      }
    }
    return result;
  }

  List<List<double>> _matrixMultiply(List<List<double>> A, List<List<double>> B) {
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

  List<double> _applyThreshold(List<double> values) {
    const double threshold = 0.01;
    return values.map((value) => value.abs() < threshold ? 0.0 : value).toList();
  }

  List<List<double>> _matrixAdd(List<List<double>> A, List<List<double>> B) {
    int rows = A.length;
    int cols = A[0].length;
    List<List<double>> result = List.generate(rows, (_) => List.filled(cols, 0.0));
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[i][j] = A[i][j] + B[i][j];
      }
    }
    return result;
  }

  List<List<double>> _matrixSubtract(List<List<double>> A, List<List<double>> B) {
    int rows = A.length;
    int cols = A[0].length;
    List<List<double>> result = List.generate(rows, (_) => List.filled(cols, 0.0));
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[i][j] = A[i][j] - B[i][j];
      }
    }
    return result;
  }

  /// Computes the inverse of a square matrix.
  /// Returns null if the matrix is not invertible.
  List<List<double>>? _inverse(List<List<double>> matrix) {
    final n = matrix.length;

    // Validate that the matrix is square
    if (matrix.any((row) => row.length != n)) {
      throw ArgumentError('Matrix must be square.');
    }

    // Initialize the identity matrix
    final identity = List.generate(
      n,
          (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0),
    );

    // Augment the original matrix with the identity matrix
    final augmented = List.generate(
      n,
          (i) => [...matrix[i], ...identity[i]],
    );

    // Perform Gaussian elimination
    for (int i = 0; i < n; i++) {
      // Find the pivot element
      int pivotRow = i;
      for (int row = i + 1; row < n; row++) {
        if (augmented[row][i].abs() > augmented[pivotRow][i].abs()) {
          pivotRow = row;
        }
      }

      // Swap rows if needed
      if (pivotRow != i) {
        final temp = augmented[i];
        augmented[i] = augmented[pivotRow];
        augmented[pivotRow] = temp;
      }

      // Check if the matrix is singular
      if (augmented[i][i].abs() < 1e-10) {
        return null; // Not invertible
      }

      // Scale the pivot row to make the pivot element 1
      final pivot = augmented[i][i];
      for (int j = 0; j < 2 * n; j++) {
        augmented[i][j] /= pivot;
      }

      // Eliminate the column
      for (int row = 0; row < n; row++) {
        if (row != i) {
          final factor = augmented[row][i];
          for (int j = 0; j < 2 * n; j++) {
            augmented[row][j] -= factor * augmented[i][j];
          }
        }
      }
    }

    // Extract the inverse matrix
    return List.generate(
      n,
          (i) => augmented[i].sublist(n),
    );
  }

  List<List<double>> _pseudoinverse(List<List<double>> matrix) {
    final matrix4 = Matrix4.zero(); // Create a 4x4 matrix (Matrix4 is a 4x4 matrix)

    // Convert the 2D List to a Matrix4 for matrix operations.
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        matrix4.setEntry(i, j, matrix[i][j]);
      }
    }

    // Calculate the Moore-Penrose Pseudoinverse using Matrix4
    final pseudoinverse = matrix4.clone()..invert(); // This computes the pseudoinverse

    // Convert the Matrix4 result back to a 2D List
    List<List<double>> result = List.generate(4, (_) => List.filled(4, 0.0));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        result[i][j] = pseudoinverse.entry(i, j);
      }
    }
    return result;
  }


  List<List<double>> _identityMatrix(int size) {
    return List.generate(size, (i) => List.generate(size, (j) => i == j ? 1.0 : 0.0));
  }

  void updateWithGPS(LatLng gpsPoint, double vx, double vy) {
    CoordinateTransform transform = CoordinateTransform(_referencePoint);
    List<double> enuCoordinates = transform.gpsToENU(gpsPoint);

    List<double> gpsData = [enuCoordinates[0], enuCoordinates[1], vx, vy];
    update(gpsData);
  }

  List<double> get state => _state;
}