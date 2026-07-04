import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../models/analysis_result.dart';
import '../../models/chat_message.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/chat_event.dart';
import 'bloc/chat_state.dart';

class ChatScreen extends StatefulWidget {
  final AnalysisResult result;

  const ChatScreen({super.key, required this.result});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(text));
    _controller.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: widget.result.productName ?? 'Tanya AI'),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: state.messages.isEmpty && !state.isSending
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            state.messages.length + (state.isSending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == state.messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildBubble(context, state.messages[i]);
                        },
                      ),
              ),
              if (state.errorMessage != null)
                _buildErrorBanner(context, state.errorMessage!),
              _buildInputBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tanya apa saja tentang produk ini — misalnya keamanannya untuk kondisi tertentu, atau alasan rating suatu bahan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text.rich(
          TextSpan(
            children: _parseInlineMarkdown(
              message.text,
              TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ponytail: parser inline minimal (bold **x**, italic *x*) — jawaban chat
  // cuma perlu penekanan kata, bukan markdown dokumen penuh (heading, list,
  // code block, dll), jadi tidak perlu package markdown penuh.
  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle baseStyle) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return [
      for (final span in spans)
        TextSpan(
          text: (span as TextSpan).text,
          style: baseStyle.merge(span.style),
        ),
    ];
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _buildTypingDot(i)),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 7,
      height: 7,
      margin: EdgeInsets.only(left: index == 0 ? 0 : 5),
      decoration: const BoxDecoration(
        color: AppColors.textHint,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scaleXY(
          begin: 0.6,
          end: 1.0,
          duration: 400.ms,
          delay: (index * 150).ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scaleXY(begin: 1.0, end: 0.6, duration: 400.ms);
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.dangerRedLight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<ChatBloc>().add(const ChatRetryRequested()),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !state.isSending,
                decoration: const InputDecoration(
                  hintText: 'Ketik pertanyaanmu...',
                ),
                onSubmitted: (_) => _send(context),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: state.isSending ? null : () => _send(context),
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
