/// Scrub video seek kararı: saf mantık, `package:web` import etmez; VM testinde denenir (AGENTS.md §5, §11.4).
///
/// `ScrubVideoHandle` her rAF karesinde [decideSeek]'i çağırır. Tarayıcı bir seek'i bitirmeden
/// yenisi gelirse eskisini iptal eder ve kare yarım kalır; bu yüzden seek sürerken yeni hedef
/// bekletilir ve `seeked` olayından sonraki karede gönderilir.
library;

/// Bu sürenin altındaki fark bir kareden kısadır; seek atlanır (30 fps).
const double scrubSeekThreshold = 1 / 30;

/// Bir rAF karesindeki seek kararı.
enum SeekDecision {
  /// Video zaten hedefte (fark eşiğin altında); bekleyen hedef silinir.
  skip,

  /// Önceki seek sürüyor; hedef bekletilir, `seeked` gelince yeniden denenir.
  defer,

  /// `currentTime` hedefe set edilir.
  seek,
}

/// Bir rAF karesinde seek yapılıp yapılmayacağına karar verir.
///
/// `|target - current| < threshold` ise [SeekDecision.skip]; değilse [seeking] `true` ise
/// [SeekDecision.defer]; değilse [SeekDecision.seek].
SeekDecision decideSeek({
  required double target,
  required double current,
  required bool seeking,
  double threshold = scrubSeekThreshold,
}) {
  if ((target - current).abs() < threshold) return SeekDecision.skip;
  if (seeking) return SeekDecision.defer;
  return SeekDecision.seek;
}
