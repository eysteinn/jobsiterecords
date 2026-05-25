import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:jobsiterecords/core/note_markdown.dart';

void main() {
  group('note markdown roundtrip', () {
    test('plain text survives', () {
      const input = 'Remember to pick up drywall screws.';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('bold survives', () {
      const input = 'Call **John Smith** tomorrow.';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('italic survives', () {
      const input = 'Check the *shower pan* carefully.';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('bullet list survives', () {
      const input = '- First item\n- Second item';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('legacy numbered list still loads', () {
      const input = '1. First step\n2. Second step';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('legacy heading still loads', () {
      const input = '## Site walkthrough';
      expect(markdownFromDocument(documentFromMarkdown(input)), input);
    });

    test('plain text preview strips formatting', () {
      const input = '- **Bold item** and *italic*';
      expect(notePlainTextPreview(input), 'Bold item and italic');
    });

    test('markdown converts to html', () {
      final html = noteMarkdownToHtml('- **Issue** at the panel');
      expect(html, contains('<strong>Issue</strong>'));
      expect(html, contains('<ul>'));
    });
  });

  test('empty markdown is detected', () {
    expect(noteMarkdownIsEmpty(''), isTrue);
    expect(noteMarkdownIsEmpty('   '), isTrue);
    expect(noteMarkdownIsEmpty('Still plain text'), isFalse);
  });

  test('empty document serializes cleanly', () {
    expect(markdownFromDocument(Document()), '');
  });
}
