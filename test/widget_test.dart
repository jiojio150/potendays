import 'package:flutter_test/flutter_test.dart';
import 'package:potendays/main.dart';

void main() {
  test('PotenDaysApp 클래스 생성 테스트', () {
    const app = PotenDaysApp();

    expect(app, isA<PotenDaysApp>());
  });
}