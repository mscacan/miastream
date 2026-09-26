String? httpArtwork(dynamic raw, {Uri? base}) {
  var text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null' || text.toLowerCase() == 'n/a') {
    return null;
  }
  if (text.startsWith('//')) {
    text = 'http:$text';
  }
  if (base != null && text.startsWith('/')) {
    final port = base.hasPort ? ':${base.port}' : '';
    text = '${base.scheme}://${base.host}$port$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  return uri.toString();
}

String? artworkFrom(Map item, {Uri? base}) {
  const keys = ['stream_icon', 'cover', 'cover_big', 'movie_image', 'icon', 'logo', 'tvg_logo'];
  for (final key in keys) {
    final found = httpArtwork(item[key], base: base);
    if (found != null) {
      return found;
    }
  }
  final info = item['info'];
  if (info is Map) {
    for (final key in keys) {
      final found = httpArtwork(info[key], base: base);
      if (found != null) {
        return found;
      }
    }
  }
  return null;
}
