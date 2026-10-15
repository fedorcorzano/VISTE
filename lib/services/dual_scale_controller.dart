import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// Controlador matemático para permitir zoom/paneo natural con 2 dedos
/// sin interferir con el trazado y manipulación con 1 dedo.
class DualScaleController {
  final TransformationController transformationController;
  Matrix4 _startMatrix = Matrix4.identity();
  Offset _startFocal = Offset.zero;
  bool isZooming = false;

  DualScaleController({TransformationController? controller})
      : transformationController = controller ?? TransformationController();

  void onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      isZooming = true;
      _startMatrix = transformationController.value.clone();
      _startFocal = details.localFocalPoint;
    } else {
      isZooming = false;
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details, Size viewportSize) {
    if (details.pointerCount >= 2 || isZooming) {
      isZooming = true;
      final scale = details.scale;
      final currentFocal = details.localFocalPoint;

      // Cálculo de punto focal en coordenadas de escena
      final Matrix4 inverse = Matrix4.inverted(_startMatrix);
      final Offset sceneFocal = MatrixUtils.transformPoint(inverse, _startFocal);

      // Nueva matriz escalada y desplazada
      final newMatrix = Matrix4.identity()
        ..translateByVector3(v64.Vector3(currentFocal.dx, currentFocal.dy, 0.0))
        ..scaleByVector3(v64.Vector3(scale, scale, 1.0))
        ..translateByVector3(v64.Vector3(-sceneFocal.dx, -sceneFocal.dy, 0.0));

      final double resultingScale = newMatrix.getMaxScaleOnAxis();
      if (resultingScale >= 1.0 && resultingScale <= 5.0) {
        transformationController.value = newMatrix;
      }
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    isZooming = false;
    if (transformationController.value.getMaxScaleOnAxis() < 1.0) {
      transformationController.value = Matrix4.identity();
    }
  }

  void reset() {
    transformationController.value = Matrix4.identity();
    isZooming = false;
  }
}
