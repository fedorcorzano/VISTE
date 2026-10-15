import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/services/dual_scale_controller.dart';

void main() {
  test('DualScaleController handles pinch zoom and clamping', () {
    final controller = DualScaleController();

    controller.onScaleStart(ScaleStartDetails(
      pointerCount: 2,
      localFocalPoint: const Offset(150, 150),
    ));

    expect(controller.isZooming, isTrue);

    controller.onScaleUpdate(
      ScaleUpdateDetails(
        pointerCount: 2,
        scale: 2.0,
        localFocalPoint: const Offset(150, 150),
      ),
      const Size(300, 300),
    );

    expect(controller.transformationController.value.getMaxScaleOnAxis(), closeTo(2.0, 0.01));

    controller.onScaleEnd(ScaleEndDetails());
    expect(controller.isZooming, isFalse);

    controller.reset();
    expect(controller.transformationController.value.getMaxScaleOnAxis(), 1.0);
  });

  test('Viewport to scene coordinate transformation works accurately when zoomed', () {
    final controller = DualScaleController();
    // Simulate 2x zoom centered at (150, 150)
    controller.onScaleStart(ScaleStartDetails(pointerCount: 2, localFocalPoint: const Offset(150, 150)));
    controller.onScaleUpdate(
      ScaleUpdateDetails(pointerCount: 2, scale: 2.0, localFocalPoint: const Offset(150, 150)),
      const Size(300, 300),
    );

    final matrix = controller.transformationController.value;
    final Matrix4 inverse = Matrix4.inverted(matrix);

    // Center of screen (150, 150) should map to scene (150, 150)
    final sceneCenter = MatrixUtils.transformPoint(inverse, const Offset(150, 150));
    expect(sceneCenter.dx, closeTo(150, 0.01));
    expect(sceneCenter.dy, closeTo(150, 0.01));

    // Screen point (0, 0) when zoomed 2x centered at 150 should map to scene (75, 75)
    final sceneOrigin = MatrixUtils.transformPoint(inverse, const Offset(0, 0));
    expect(sceneOrigin.dx, closeTo(75, 0.01));
    expect(sceneOrigin.dy, closeTo(75, 0.01));
  });
}
