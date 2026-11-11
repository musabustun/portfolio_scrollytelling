import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/widgets/label_text.dart';

/// upperTr: Türkçe kurallı BÜYÜK HARF (i → İ, ı → I; AGENTS.md §10.3).
void main() {
  group('upperTr', () {
    test('noktalı i büyük İ olur', () {
      expect(upperTr('Ben kimim?'), 'BEN KİMİM?');
    });

    test('noktasız ı büyük I olur', () {
      expect(upperTr('ışık'), 'IŞIK');
    });

    test('ı, ç ve ş birlikte', () {
      expect(upperTr('Nasıl çalışıyorum?'), 'NASIL ÇALIŞIYORUM?');
    });

    test('zaten büyük İ korunur', () {
      expect(upperTr('İletişim'), 'İLETİŞİM');
    });

    test('ğ, ü, ö doğru çevrilir', () {
      expect(upperTr('güzel öğün'), 'GÜZEL ÖĞÜN');
    });

    test('boş metin boş kalır', () {
      expect(upperTr(''), '');
    });
  });
}
