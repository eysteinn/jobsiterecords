import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../app/theme.dart';

class NoteBodyView extends StatelessWidget {
  const NoteBodyView({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkdownBody(
      data: markdown,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.45),
        h1: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.3,
        ),
        h2: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.3,
        ),
        listBullet: const TextStyle(fontSize: 14, color: AppColors.ink),
        listIndent: 20,
        blockSpacing: 8,
        strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
        em: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.ink),
      ),
    );
  }
}
