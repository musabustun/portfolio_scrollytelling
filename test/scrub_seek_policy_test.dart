import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_scrollytelling/web/scrub_seek_policy.dart';

/// Scrub seek kapısı (AGENTS.md §5): eşik altı atlanır, seek sürerken beklenir, yoksa seek edilir.
void main() {
  group('decideSeek', () {
    test('eşik altındaki fark atlanır', () {
      expect(
        decideSeek(target: 2.0, current: 2.01, seeking: false),
        SeekDecision.skip,
      );
      expect(
        decideSeek(target: 2.01, current: 2.0, seeking: false),
        SeekDecision.skip,
      );
    });

    test('eşik altındaki fark seek sürerken de atlanır (skip önce gelir)', () {
      expect(
        decideSeek(target: 2.0, current: 2.01, seeking: true),
        SeekDecision.skip,
      );
    });

    test('seek sürerken yeni hedef bekletilir', () {
      expect(
        decideSeek(target: 5.0, current: 2.0, seeking: true),
        SeekDecision.defer,
      );
    });

    test('seek yokken uzak hedefe seek edilir, iki yönde de', () {
      expect(
        decideSeek(target: 5.0, current: 2.0, seeking: false),
        SeekDecision.seek,
      );
      expect(
        decideSeek(target: 2.0, current: 5.0, seeking: false),
        SeekDecision.seek,
      );
    });

    test('fark tam eşikte atlanmaz', () {
      expect(
        decideSeek(target: scrubSeekThreshold, current: 0, seeking: false),
        SeekDecision.seek,
      );
      expect(
        decideSeek(target: scrubSeekThreshold, current: 0, seeking: true),
        SeekDecision.defer,
      );
    });

    test('özel eşik varsayılanı ezer', () {
      expect(
        decideSeek(target: 1.0, current: 1.2, seeking: false, threshold: 0.5),
        SeekDecision.skip,
      );
      expect(
        decideSeek(target: 1.0, current: 1.2, seeking: false, threshold: 0.1),
        SeekDecision.seek,
      );
    });

    test('varsayılan eşik bir kare (1/30 sn)', () {
      expect(scrubSeekThreshold, closeTo(1 / 30, 1e-12));
    });

    group('clamp edilmiş hedefler (progress 0 ve 1)', () {
      const duration = 8.0;

      test('başta duran video 0 hedefini atlar', () {
        expect(
          decideSeek(target: 0, current: 0, seeking: false),
          SeekDecision.skip,
        );
      });

      test('sonda duran video süre hedefini atlar', () {
        expect(
          decideSeek(target: duration, current: duration, seeking: false),
          SeekDecision.skip,
        );
      });

      test('ortadaki video başa ve sona seek edilir', () {
        expect(
          decideSeek(target: 0, current: 4.0, seeking: false),
          SeekDecision.seek,
        );
        expect(
          decideSeek(target: duration, current: 4.0, seeking: false),
          SeekDecision.seek,
        );
      });
    });
  });
}
