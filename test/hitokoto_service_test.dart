import 'package:flutter_test/flutter_test.dart';
import 'package:tomato_clock/hitokoto_service.dart';

void main() {
  group('HitokotoService', () {
    test('parses quote json', () {
      final quote = HitokotoService.parseQuote(
        '{"hitokoto":"把注意力收回来。","from":"测试出处","from_who":"作者"}',
      );

      expect(quote, isNotNull);
      expect(quote!.text, '把注意力收回来。');
      expect(quote.source, '作者');
    });

    test('rejects invalid or oversized quote', () {
      expect(HitokotoService.parseQuote('{}'), isNull);
      expect(HitokotoService.parseQuote('not json'), isNull);
      expect(
        HitokotoService.parseQuote(
          '{"hitokoto":"这是一条长度明显超过界面短句限制的一言内容，用于避免网络返回导致布局被撑开的情况。"}',
        ),
        isNull,
      );
    });
  });
}
