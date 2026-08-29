import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class FlashExchangeScreen extends StatefulWidget {
  const FlashExchangeScreen({super.key});

  @override
  State<FlashExchangeScreen> createState() => _FlashExchangeScreenState();
}

class _FlashExchangeScreenState extends State<FlashExchangeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _detectedAddress = "";
  bool _hasUserMessage = false;
  bool _isDetected = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _detectAddress() {
    final raw = _messageController.text.trim();
    if (raw.isEmpty) return;

    final evmRegex = RegExp(r'0x[a-fA-F0-9]{40}');
    final solanaRegex = RegExp(r'\b[1-9A-HJ-NP-Za-km-z]{32,44}\b');

    final evmMatch = evmRegex.firstMatch(raw);
    final solanaMatch = solanaRegex.firstMatch(raw);

    setState(() {
      if (evmMatch != null) {
        _detectedAddress = evmMatch.group(0)!;
        _isDetected = true;
      } else if (solanaMatch != null) {
        _detectedAddress = solanaMatch.group(0)!;
        _isDetected = true;
      } else {
        _detectedAddress = "";
        _isDetected = false;
      }
      _hasUserMessage = true;
    });

    // Auto scroll to bottom to show results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text == null) return;

    final value = clipboard!.text!.trim();
    if (value.isEmpty) return;

    setState(() {
      _messageController.text = value;
    });
  }

  Future<void> _copyAddress() async {
    if (_detectedAddress.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _detectedAddress));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        useSafeArea: false,
        appBar: AppBar(
          title: const Text('Flash Exchange'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _buildBotMessage(
                    context,
                    "Welcome to Flash Exchange! Send me a contract address or wallet address to get started.",
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
                  if (_hasUserMessage) ...[
                    const SizedBox(height: 20),
                    _buildUserMessage(context, _messageController.text).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0),
                    const SizedBox(height: 20),
                    (_isDetected ? _buildDetectedTokenCard(context) : _buildUnsupportedCard(context)).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
                  ],
                ],
              ),
            ),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBotMessage(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          child: Icon(Icons.flash_on_rounded, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onPrimary),
        ),
      ),
    );
  }

  Widget _buildDetectedTokenCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.primary.withValues(alpha: 0.1),
          child: Icon(Icons.flash_on_rounded, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Address Detected", style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _detectedAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(fontFamily: "monospace"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _copyAddress,
                        child: Icon(Icons.copy_rounded, size: 16, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _actionButton(context, icon: Icons.shopping_cart_rounded, label: "Buy", primary: true, onTap: () {}),
                    const SizedBox(width: 8),
                    _actionButton(context, icon: Icons.sell_rounded, label: "Sell", onTap: () {}),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _actionButton(context, icon: Icons.show_chart_rounded, label: "Chart", onTap: () {}),
                    const SizedBox(width: 8),
                    _actionButton(context, icon: Icons.open_in_new_rounded, label: "View", onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupportedCard(BuildContext context) {
    return _buildBotMessage(context, "I couldn't find a supported wallet or contract address in that message.");
  }

  Widget _actionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: primary
            ? ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 18),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Paste address or message...",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: colors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _detectAddress,
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
