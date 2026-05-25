import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../app/theme.dart';
import '../../../core/note_markdown.dart';

class NoteEditorController {
  QuillController? _quill;

  void _bind(QuillController quill) {
    _quill = quill;
  }

  String get markdown {
    final quill = _quill;
    if (quill == null) return '';
    return markdownFromDocument(quill.document);
  }

  bool get isEmpty => noteMarkdownIsEmpty(markdown);
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.controller,
    this.initialMarkdown = '',
    this.minHeight = 160,
    this.autofocus = false,
    this.placeholder = 'What do you want to remember?',
  });

  final NoteEditorController controller;
  final String initialMarkdown;
  final double minHeight;
  final bool autofocus;
  final String placeholder;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final QuillController _quillController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _quillController = QuillController(
      document: documentFromMarkdown(widget.initialMarkdown),
      selection: const TextSelection.collapsed(offset: 0),
    );
    widget.controller._bind(_quillController);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: QuillSimpleToolbar(
            controller: _quillController,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showAlignmentButtons: false,
              showHeaderStyle: false,
              showListNumbers: false,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showUndo: true,
              showRedo: true,
              showDirection: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _focusNode,
                scrollController: _scrollController,
                config: QuillEditorConfig(
                  placeholder: widget.placeholder,
                  padding: EdgeInsets.zero,
                  scrollable: false,
                  autoFocus: widget.autofocus,
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      const TextStyle(fontSize: 15, color: AppColors.ink, height: 1.45),
                      const HorizontalSpacing(0, 0),
                      const VerticalSpacing(0, 8),
                      const VerticalSpacing(0, 0),
                      null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
