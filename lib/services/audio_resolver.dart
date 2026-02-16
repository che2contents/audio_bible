class AudioResolver {
  static const Map<String, String> _bookToPrefix = {
    "창세기": "gen",
    "출애굽기": "exo",
    // 필요하면 추가:
    // "레위기": "lev",
    // "민수기": "num",
    // "신명기": "deu",
  };

  static String? forRange({
    required String book,
    required int startChapter,
    required int endChapter,
    String ext = "mp3",
  }) {
    final prefix = _bookToPrefix[book];
    if (prefix == null) return null; // 매핑 없으면 오디오 없음 처리

    return "audio/${prefix}${startChapter}-${endChapter}.$ext";
  }
}
