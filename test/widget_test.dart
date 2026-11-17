import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestion_llaves/core/utils/key_nomenclature_generator.dart';
import 'package:gestion_llaves/features/camera_vector/domain/services/key_vectorizer_service.dart';
import 'package:gestion_llaves/main.dart';

void main() {
  test('Módulo A: Regla de nomenclatura jerárquica genera BELG-04-DEPB-01', () {
    final code = KeyNomenclatureGenerator.generateCode(
      idEdificio: 'BELG',
      pisoDepto: '04-DEPB',
      correlativo: 1,
    );
    expect(code, equals('BELG-04-DEPB-01'));
    expect(KeyNomenclatureGenerator.isValid(code), isTrue);
  });

  test('Módulo B: Vectorización y Matching matemático discrimina llaves', () {
    final targetKey = KeyVectorizerService.generateFromBittingHeights(
      bittingDepthsMm: const [7.6, 5.1, 6.8, 4.3, 7.2, 5.4],
      bladeLengthMm: 28.5,
    );
    final orphanSameKeyWithOpticalNoise =
        KeyVectorizerService.generateFromBittingHeights(
      bittingDepthsMm: const [7.6, 5.1, 6.8, 4.3, 7.2, 5.4],
      bladeLengthMm: 28.5,
      noiseAmplitudeMm: 0.08,
    );
    final differentKey = KeyVectorizerService.generateFromBittingHeights(
      bittingDepthsMm: const [4.0, 8.1, 3.9, 8.0, 4.2, 7.9],
      bladeLengthMm: 31.0,
    );

    final matchSame = KeyVectorizerService.compareKeyVectors(
      orphanSameKeyWithOpticalNoise.contourMm,
      targetKey.contourMm,
    );
    final matchDifferent = KeyVectorizerService.compareKeyVectors(
      differentKey.contourMm,
      targetKey.contourMm,
    );

    expect(matchSame.matchPercentage, greaterThan(92.0));
    expect(matchSame.matchPercentage, greaterThan(matchDifferent.matchPercentage));
  });

  testWidgets('Renderiza aplicación multiplataforma KeyVector Control',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KeyVectorControlApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('KEYVECTOR ERP'), findsOneWidget);
    expect(find.textContaining('BELG-04-DEPB-01'), findsWidgets);
  });
}
