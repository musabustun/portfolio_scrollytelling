// Testler için deterministik `AskFn`: sabit cevabı sahte zamanda kelime kelime akıtır.
// Üretimde yeri yok; uygulama `PersonaService.ask` kullanır, Firebase yoksa panel kart gösterir.

/// Sahte cevap; [fakeAsk]'ın parçaları birleşince tam bu metin olur.
const String fakeReply = 'Sahte cevap kelime kelime akar.';

/// İlk kelimeden önceki bekleme.
const Duration fakeReplyDelay = Duration(milliseconds: 400);

/// Kelimeler arası akış aralığı.
const Duration fakeWordInterval = Duration(milliseconds: 60);

/// `AskFn` imzası: [fakeReplyDelay] bekler, [fakeReply]'ı kelime kelime akıtır.
///
/// Parçalar birleşince metin [fakeReply]'ın tam kendisidir (ilk kelime hariç her parça
/// boşlukla başlar).
Future<Stream<String>> fakeAsk(String question) async {
  await Future<void>.delayed(fakeReplyDelay);
  return _words();
}

/// `async*` üreteci, `Stream.periodic(...).take(n)` değil: periodic'in iptal future'ı kök zone'da
/// tamamlanır, widget testinin sahte zamanında "bitti" olayı hiç gelmez ve panel akışta takılı kalır.
Stream<String> _words() async* {
  final words = fakeReply.split(' ');
  for (var i = 0; i < words.length; i++) {
    await Future<void>.delayed(fakeWordInterval);
    yield i == 0 ? words[i] : ' ${words[i]}';
  }
}
