import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vistec/models/linear_measurement_model.dart';
import 'package:vistec/models/sticker_model.dart';
import 'package:vistec/services/technical_catalog_icons.dart';

void main() {
  group('Mejoras VISTEC - Iconos Técnicos Personalizados (Req. 8)', () {
    test('Estructuras retornan iconos específicos para cada material base', () {
      expect(TechnicalCatalogIcons.getStructureIcon('Madera'), Icons.forest_outlined);
      expect(TechnicalCatalogIcons.getStructureIcon('Fierro'), Icons.hardware);
      expect(TechnicalCatalogIcons.getStructureIcon('Acero estructural'), Icons.hardware);
      expect(TechnicalCatalogIcons.getStructureIcon('Ladrillo caravista'), Icons.grid_view_rounded);
      expect(TechnicalCatalogIcons.getStructureIcon('Vidrio templado'), Icons.window_outlined);
      expect(TechnicalCatalogIcons.getStructureIcon('Concreto armado'), Icons.foundation);
      expect(TechnicalCatalogIcons.getStructureIcon('Drywall tabiquería'), Icons.layers_outlined);
      expect(TechnicalCatalogIcons.getStructureIcon('Mayólica / Cerámica'), Icons.grid_on);
      expect(TechnicalCatalogIcons.getStructureIcon('Policarbonato alveolar'), Icons.solar_power_outlined);
      expect(TechnicalCatalogIcons.getStructureIcon('Teja andina'), Icons.roofing);
    });

    test('Materiales y canalizaciones retornan iconos representativos', () {
      expect(TechnicalCatalogIcons.getMaterialIcon('Tubo EMT 3/4"'), Icons.linear_scale);
      expect(TechnicalCatalogIcons.getMaterialIcon('Tubo IMC 1"'), Icons.line_weight);
      expect(TechnicalCatalogIcons.getMaterialIcon('Canaleta 40x25'), Icons.view_column_rounded);
      expect(TechnicalCatalogIcons.getMaterialIcon('Tubo PVC SAP 3/4"'), Icons.water_drop_outlined);
      expect(TechnicalCatalogIcons.getMaterialIcon('Tubo Liquid Tight 1/2"'), Icons.waves);
      expect(TechnicalCatalogIcons.getMaterialIcon('Bandeja portacables 200mm'), Icons.table_rows_outlined);
      expect(TechnicalCatalogIcons.getMaterialIcon('Caja de paso 100x100'), Icons.check_box_outline_blank);
      expect(TechnicalCatalogIcons.getMaterialIcon('Tubo Corrugado'), Icons.all_inclusive);
      expect(TechnicalCatalogIcons.getMaterialIcon('Cable UTP Cat6'), Icons.cable);
    });

    test('StickerModel.fromCatalog integra TechnicalCatalogIcons', () {
      final stickerMadera = StickerModel.fromCatalog('Madera', StickerCategory.estructuras);
      expect(stickerMadera.icon, Icons.forest_outlined);

      final stickerEmt = StickerModel.fromCatalog('Tubo EMT 3/4"', StickerCategory.materiales);
      expect(stickerEmt.icon, Icons.linear_scale);

      final stickerLadrillo = StickerModel.fromCatalog('Ladrillo', StickerCategory.estructuras);
      expect(stickerLadrillo.icon, Icons.grid_view_rounded);
    });
  });

  group('Mejoras VISTEC - Priorización de Materiales y Ajuste de Cotas (Req. 2, 3, 6)', () {
    test('Materiales prioritarios para proyecto Comercial se ordenan al inicio', () {
      final items = ['Canaleta 40x25', 'Tubo PVC SAP 1"', 'Tubo EMT', 'Cable UTP'];
      final priorityList = TechnicalCatalogMatrix.materialesPorClasificacion['Comercial'] ?? [];

      items.sort((a, b) {
        final aPri = priorityList.contains(a);
        final bPri = priorityList.contains(b);
        if (aPri && !bPri) return -1;
        if (!aPri && bPri) return 1;
        return a.compareTo(b);
      });

      // Tubo EMT es prioritario en Comercial
      expect(priorityList.contains(items.first), isTrue);
      expect(items.first, 'Tubo EMT');
    });

    test('LinearMeasurement copyWith permite corregir manija A y manija B con precisión', () {
      final original = LinearMeasurement(
        id: 'cota-1',
        startOffset: const Offset(100, 100),
        endOffset: const Offset(200, 100),
        material: 'Tubo EMT 3/4"',
        longitudMetros: 5.0,
      );

      // Desplazamiento de manija A
      final adjustedA = original.copyWith(startOffset: const Offset(110, 105));
      expect(adjustedA.startOffset, const Offset(110, 105));
      expect(adjustedA.endOffset, const Offset(200, 100));
      expect(adjustedA.material, 'Tubo EMT 3/4"');

      // Desplazamiento de manija B
      final adjustedB = adjustedA.copyWith(endOffset: const Offset(215, 120));
      expect(adjustedB.startOffset, const Offset(110, 105));
      expect(adjustedB.endOffset, const Offset(215, 120));
    });
  });
}
