import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as md;

/// Loads stored markdown into a Quill [Document] for editing.
Document documentFromMarkdown(String markdown) {
  if (markdown.trim().isEmpty) {
    return Document();
  }

  final delta = Delta();
  final lines = markdown.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    var content = rawLine;
    Map<String, dynamic>? blockAttrs;

    final headingMatch = RegExp(r'^## (.+)$').firstMatch(rawLine);
    if (headingMatch != null) {
      content = headingMatch.group(1)!;
      blockAttrs = Attribute.h2.toJson();
    } else if (rawLine.startsWith('- ')) {
      content = rawLine.substring(2);
      blockAttrs = Attribute.ul.toJson();
    } else {
      final orderedMatch = RegExp(r'^(\d+)\. (.+)$').firstMatch(rawLine);
      if (orderedMatch != null) {
        content = orderedMatch.group(2)!;
        blockAttrs = Attribute.ol.toJson();
      }
    }

    _appendInlineMarkdown(delta, content);
    delta.insert('\n', blockAttrs);
  }

  return Document.fromDelta(delta);
}

/// Serializes a Quill [Document] to markdown for storage in [items.body].
String markdownFromDocument(Document document) {
  final delta = document.toDelta();
  final result = StringBuffer();
  final lineBuffer = StringBuffer();
  var orderedIndex = 1;

  void finishLine(Map<String, dynamic>? blockAttrs) {
    final line = lineBuffer.toString();
    lineBuffer.clear();

    if (blockAttrs != null) {
      final header = blockAttrs[Attribute.header.key];
      if (header == 2) {
        result.writeln('## $line');
        orderedIndex = 1;
        return;
      }
      final list = blockAttrs[Attribute.list.key];
      if (list == 'bullet') {
        result.writeln('- $line');
        orderedIndex = 1;
        return;
      }
      if (list == 'ordered') {
        result.writeln('$orderedIndex. $line');
        orderedIndex++;
        return;
      }
    }

    result.writeln(line);
    orderedIndex = 1;
  }

  for (final op in delta.toList()) {
    if (!op.isInsert) continue;
    final text = op.data;
    if (text is! String) continue;

    if (text == '\n') {
      finishLine(op.attributes);
      continue;
    }

    if (text.contains('\n')) {
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        _appendFormattedText(lineBuffer, parts[i], op.attributes);
        if (i < parts.length - 1) {
          finishLine(null);
        }
      }
      continue;
    }

    _appendFormattedText(lineBuffer, text, op.attributes);
  }

  final output = result.toString();
  if (output.endsWith('\n')) {
    return output.substring(0, output.length - 1);
  }
  return output;
}

bool noteMarkdownIsEmpty(String? markdown) {
  if (markdown == null || markdown.trim().isEmpty) return true;
  return documentFromMarkdown(markdown).toPlainText().trim().isEmpty;
}

String notePlainTextPreview(String? markdown) {
  if (markdown == null || markdown.trim().isEmpty) return '';
  return documentFromMarkdown(markdown).toPlainText().trim();
}

String noteMarkdownToHtml(String markdown) {
  if (markdown.trim().isEmpty) return '';
  return md.markdownToHtml(
    markdown,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );
}

void _appendInlineMarkdown(Delta delta, String text) {
  var index = 0;
  while (index < text.length) {
    if (text.startsWith('**', index)) {
      final end = text.indexOf('**', index + 2);
      if (end != -1) {
        delta.insert(
          text.substring(index + 2, end),
          {Attribute.bold.key: true},
        );
        index = end + 2;
        continue;
      }
    }

    if (text[index] == '*' &&
        (index + 1 >= text.length || text[index + 1] != '*')) {
      final end = text.indexOf('*', index + 1);
      if (end != -1) {
        delta.insert(
          text.substring(index + 1, end),
          {Attribute.italic.key: true},
        );
        index = end + 1;
        continue;
      }
    }

    final nextSpecial = _nextInlineSpecial(text, index);
    delta.insert(text.substring(index, nextSpecial));
    index = nextSpecial;
  }
}

int _nextInlineSpecial(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (text.startsWith('**', i) || text[i] == '*') {
      return i;
    }
  }
  return text.length;
}

void _appendFormattedText(
  StringBuffer buffer,
  String text,
  Map<String, dynamic>? attrs,
) {
  if (text.isEmpty) return;

  final bold = attrs?[Attribute.bold.key] == true;
  final italic = attrs?[Attribute.italic.key] == true;

  if (bold && italic) {
    buffer.write('***$text***');
    return;
  }
  if (bold) {
    buffer.write('**$text**');
    return;
  }
  if (italic) {
    buffer.write('*$text*');
    return;
  }
  buffer.write(text);
}
