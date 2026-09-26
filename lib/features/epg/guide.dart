class GuideSlot {
  const GuideSlot({
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
  });

  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
}

List<GuideSlot> parseXmltv(String xml) {
  final slots = <GuideSlot>[];
  final blocks = RegExp(r'<programme\b([^>]*)>([\s\S]*?)</programme>', caseSensitive: false);
  for (final match in blocks.allMatches(xml)) {
    if (slots.length >= 20000) {
      break;
    }
    final attrs = match.group(1) ?? '';
    final body = match.group(2) ?? '';
    final start = _attr(attrs, 'start');
    final stop = _attr(attrs, 'stop');
    final channel = _attr(attrs, 'channel');
    if (start == null || stop == null || channel == null) {
      continue;
    }
    final startAt = parseXmltvTime(start);
    final endAt = parseXmltvTime(stop);
    if (startAt == null || endAt == null) {
      continue;
    }
    final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(body);
    final title = _unescape(titleMatch?.group(1)?.trim() ?? '');
    if (title.isEmpty) {
      continue;
    }
    slots.add(GuideSlot(channelId: channel, start: startAt, end: endAt, title: title));
  }
  slots.sort((a, b) => a.start.compareTo(b.start));
  return slots;
}

DateTime? parseXmltvTime(String raw) {
  final match = RegExp(r'(\d{14})\s*([+-]\d{4})?').firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  final digits = match.group(1)!;
  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));
  final hour = int.parse(digits.substring(8, 10));
  final minute = int.parse(digits.substring(10, 12));
  final second = int.parse(digits.substring(12, 14));
  var moment = DateTime.utc(year, month, day, hour, minute, second);
  final zone = match.group(2);
  if (zone != null && zone.length == 5) {
    final sign = zone.startsWith('-') ? -1 : 1;
    final hours = int.parse(zone.substring(1, 3));
    final minutes = int.parse(zone.substring(3, 5));
    moment = moment.subtract(Duration(hours: sign * hours, minutes: sign * minutes));
  }
  return moment.toLocal();
}

String? _attr(String attrs, String name) {
  final match = RegExp('$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(attrs);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String _unescape(String raw) {
  return raw
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
