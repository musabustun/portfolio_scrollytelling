import 'package:web/web.dart' as web;

/// [url]'i yeni sekmede açar; açılan sayfa bu sayfaya `window.opener` ile erişemez.
void openExternal(String url) =>
    web.window.open(url, '_blank', 'noopener,noreferrer');
