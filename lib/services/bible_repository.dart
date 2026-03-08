import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class BibleRepository {
  static const Map<String, String> _bookToAsset = {
    "창세기": "assets/bible/창세기.json",
    "출애굽기": "assets/bible/출애굽기.json",
    "레위기": "assets/bible/레위기.json",
    "민수기": "assets/bible/민수기.json",
    "신명기": "assets/bible/신명기.json",
    "여호수아": "assets/bible/여호수아.json",
    "사사기": "assets/bible/사사기.json",
    "룻기": "assets/bible/룻기.json",
    "사무엘상": "assets/bible/사무엘상.json",
  };

  Future<Map<String, dynamic>> loadBook(String book) async {
    final path = _bookToAsset[book];
    if (path == null) {
      throw Exception('성경 JSON 매핑이 없습니다: $book');
    }

    final raw = await rootBundle.loadString(path);
    final jsonMap = json.decode(raw);
    if (jsonMap is! Map<String, dynamic>) {
      throw Exception('JSON 형식이 올바르지 않습니다: $path');
    }
    return jsonMap;
  }

  List<String> chapterVerses(Map<String, dynamic> bookJson, int chapter) {
    final key = chapter.toString();

    dynamic node = bookJson[key];
    node ??= (bookJson["chapters"] is Map
        ? (bookJson["chapters"] as Map)[key]
        : null);

    if (node == null) return const [];

    // 1) ["절1", "절2"] 형태
    if (node is List) {
      return node.map((e) => e.toString()).toList();
    }

    // 2) {"1":"본문", "2":"본문"} 형태
    if (node is Map) {
      // verses 키가 따로 있는 경우
      final verses = node["verses"];
      if (verses is List) {
        return verses.map((e) => e.toString()).toList();
      }

      // 절 번호 key를 정렬해서 본문만 반환
      final entries = node.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });

      return entries.map((e) => e.value.toString()).toList();
    }

    return const [];
  }
}
