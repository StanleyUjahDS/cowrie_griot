import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/widgets/griot_bottom_sheet.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../users/models/user_model.dart';
import '../../../users/providers/user_provider.dart';
import '../../../wallet/models/token_model.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../wallet/utils/chain_assets.dart';
import '../../models/chat_user.dart';
import '../../models/conversation_model.dart';
import '../../providers/messaging_provider.dart';

enum _TipAudience { friends, selectedPeople }

class TipSheet extends StatefulWidget {
  final List<ChatUser> initialRecipients;
  final String? conversationId;
  final ConversationType? conversationType;
  final bool showHeader; // Optimization: hide top part if needed

  const TipSheet({
    super.key,
    required this.initialRecipients,
    this.conversationId,
    this.conversationType,
    this.showHeader = true,
  });

  static void show(
    BuildContext context, {
    required List<ChatUser> recipients,
    String? conversationId,
    ConversationType? conversationType,
    bool showHeader = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TipSheet(
        initialRecipients: recipients,
        conversationId: conversationId,
        conversationType: conversationType,
        showHeader: showHeader,
      ),
    );
  }

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  final TextEditingController amountController = TextEditingController();

  TokenModel? _selectedToken;
  bool _isUsdInput = false;
  String? _status;
  bool isPreparing = false;
  bool _differentAmounts = false;
  late List<ChatUser> recipients;
  final Map<String, TextEditingController> _recipientAmountControllers = {};

  String? get selectedNetwork {
    final network = _selectedToken?.rawNetwork;
    return network != null ? ChainAssets.normalize(network) : null;
  }

  @override
  void initState() {
    super.initState();
    recipients = List.from(widget.initialRecipients);
    final provider = context.read<MessagingProvider>();

    if (provider.tipConfig == null) {
      provider.loadTipConfig().then((_) {
        if (mounted) _initDefaultToken();
      });
    } else {
      _initDefaultToken();
    }
  }

  void _initDefaultToken() {
    final wallet = context.read<WalletProvider>();
    final provider = context.read<MessagingProvider>();
    final tokens = _getAvailableTokens(wallet, provider);

    if (tokens.isNotEmpty) {
      setState(() {
        _selectedToken = tokens.first;
      });
    }
  }

  List<TokenModel> _getAvailableTokens(
    WalletProvider wallet,
    MessagingProvider provider,
  ) {
    if (provider.tipConfig == null) return [];
    final supportedNetworks = (provider.tipConfig!['networks'] as List)
        .map((n) => ChainAssets.normalize(n['network'].toString()))
        .toSet();

    return wallet.tokens.where((t) {
      final balance = BigInt.tryParse(t.rawBalance) ?? BigInt.zero;
      final isSupported = supportedNetworks.contains(
        ChainAssets.normalize(t.rawNetwork),
      );
      final isLegit = t.isOfficial || t.isEcosystem || t.hasMarketData;
      return balance > BigInt.zero && isSupported && isLegit;
    }).toList();
  }

  @override
  void dispose() {
    amountController.dispose();
    for (final controller in _recipientAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canCustomizeAmounts => recipients.length > 1;

  void _syncRecipientAmountControllers() {
    final ids = recipients.map((recipient) => recipient.id).toSet();
    for (final entry in _recipientAmountControllers.entries.toList()) {
      if (!ids.contains(entry.key)) {
        entry.value.dispose();
        _recipientAmountControllers.remove(entry.key);
      }
    }
    for (final recipient in recipients) {
      _recipientAmountControllers.putIfAbsent(
        recipient.id,
        () => TextEditingController(text: amountController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<MessagingProvider>();
    final wallet = context.watch<WalletProvider>();
    final availableTokens = _getAvailableTokens(wallet, provider);

    final input = double.tryParse(
      amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    final tokenAmount = _currentTokenAmount;
    final usdValue = _isUsdInput
        ? (input ?? 0.0)
        : (tokenAmount * (_selectedToken?.priceUsd ?? 0.0));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                if (widget.showHeader) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        recipients.length > 1 ? 'Batch Tip' : 'Send Tip',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Recipient Row
                _buildRecipientChip(colorScheme, theme),
                const SizedBox(height: 12),

                // Token Selector
                _buildTokenSelector(colorScheme, theme, availableTokens),
                const SizedBox(height: 12),

                if (_canCustomizeAmounts) ...[
                  _buildAmountModeSelector(colorScheme),
                  const SizedBox(height: 12),
                ],

                // Input Area
                _differentAmounts && _canCustomizeAmounts
                    ? _buildIndividualAmountInputs(colorScheme, theme)
                    : _buildInputArea(colorScheme, theme),
                const SizedBox(height: 8),

                if (!_differentAmounts && input != null && input > 0)
                  _buildEstimationBadge(
                    colorScheme,
                    theme,
                    tokenAmount,
                    usdValue,
                  ),

                const SizedBox(height: 16),

                // Custom Send Button
                _buildSendButton(colorScheme, provider, input),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientChip(ColorScheme colorScheme, ThemeData theme) {
    final bool canChange = widget.conversationType != ConversationType.dm;

    return InkWell(
      onTap: canChange
          ? () async {
              final selected = await _showRecipientSelector(
                recipients,
                conversationId: widget.conversationId,
                type: widget.conversationType,
              );
              if (selected != null) {
                setState(() => recipients = selected);
                _syncRecipientAmountControllers();
              }
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                recipients.length == 1
                    ? recipients.first.effectiveDisplayName
                    : recipients.isEmpty
                    ? 'Choose recipients'
                    : '${recipients.length} Recipients',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canChange) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTokenSelector(
    ColorScheme colorScheme,
    ThemeData theme,
    List<TokenModel> available,
  ) {
    return InkWell(
      onTap: () async {
        final selected = await _showTokenSelector(_selectedToken, available);
        if (selected != null) setState(() => _selectedToken = selected);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child:
                  _selectedToken?.imageUrl != null &&
                      _selectedToken!.imageUrl.isNotEmpty
                  ? ClipOval(child: Image.network(_selectedToken!.imageUrl))
                  : Center(
                      child: Text(
                        _selectedToken?.symbol.substring(0, 1) ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedToken?.symbol ?? 'Select Token',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (selectedNetwork != null)
              Text(
                selectedNetwork!.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountModeSelector(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tip amount',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (!_differentAmounts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              recipients.length > 1
                  ? 'The same amount will be sent to each selected person.'
                  : 'Select more than one person to set different amounts.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _amountModeButton(
                  colors,
                  label: 'Same amount',
                  selected: !_differentAmounts,
                  onPressed: () => setState(() => _differentAmounts = false),
                ),
              ),
              Expanded(
                child: _amountModeButton(
                  colors,
                  label: 'Different amounts',
                  selected: _differentAmounts,
                  onPressed: () {
                    _syncRecipientAmountControllers();
                    setState(() => _differentAmounts = true);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountModeButton(
    ColorScheme colors, {
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? colors.primary : Colors.transparent,
        foregroundColor: selected ? colors.onPrimary : colors.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildIndividualAmountInputs(ColorScheme colors, ThemeData theme) {
    _syncRecipientAmountControllers();
    return Column(
      children: recipients.map((recipient) {
        final controller = _recipientAmountControllers[recipient.id]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: recipient.profileUrl != null
                    ? NetworkImage(recipient.profileUrl!)
                    : null,
                child: recipient.profileUrl == null
                    ? Text(
                        recipient.effectiveDisplayName
                            .substring(0, 1)
                            .toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recipient.effectiveDisplayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  textAlign: TextAlign.right,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    suffixText: _isUsdInput
                        ? ' USD'
                        : ' ${_selectedToken?.symbol ?? ''}',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputArea(ColorScheme colorScheme, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  prefixText: _isUsdInput ? '\$ ' : null,
                  prefixStyle: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactTipModeButton(
                label: _selectedToken?.symbol ?? "Token",
                selected: !_isUsdInput,
                onTap: () {
                  if (!_isUsdInput) return;
                  final val = double.tryParse(amountController.text) ?? 0;
                  final price = _selectedToken?.priceUsd ?? 1.0;
                  setState(() {
                    _isUsdInput = false;
                    if (val > 0) {
                      amountController.text = (val / price)
                          .toStringAsFixed(6)
                          .replaceAll(RegExp(r'0+$'), '')
                          .replaceAll(RegExp(r'\.$'), '');
                    }
                  });
                },
              ),
              _CompactTipModeButton(
                label: 'USD',
                selected: _isUsdInput,
                onTap: () {
                  if (_isUsdInput) return;
                  final val = double.tryParse(amountController.text) ?? 0;
                  final price = _selectedToken?.priceUsd ?? 0.0;
                  setState(() {
                    _isUsdInput = true;
                    if (val > 0) {
                      amountController.text = (val * price).toStringAsFixed(2);
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstimationBadge(
    ColorScheme colorScheme,
    ThemeData theme,
    double tokenAmount,
    double usdValue,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _isUsdInput
            ? '≈ ${tokenAmount.toStringAsFixed(6)} ${_selectedToken?.symbol}'
            : '≈ \$${usdValue.toStringAsFixed(2)}',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSendButton(
    ColorScheme colorScheme,
    MessagingProvider provider,
    double? input,
  ) {
    final hasAmount = _differentAmounts && _canCustomizeAmounts
        ? recipients.any(
            (recipient) =>
                _recipientAmountControllers[recipient.id]?.text
                    .trim()
                    .isNotEmpty ==
                true,
          )
        : amountController.text.isNotEmpty;
    final bool disabled =
        !hasAmount ||
        isPreparing ||
        recipients.isEmpty ||
        _selectedToken == null;

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: disabled
            ? null
            : LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
        color: disabled ? colorScheme.onSurface.withValues(alpha: 0.1) : null,
      ),
      child: InkWell(
        onTap: disabled ? null : () => _handleSend(provider, input),
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: isPreparing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GriotLoader(
                      size: 20,
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                      useLogo: true,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _status ?? 'Preparing...',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : Text(
                  recipients.length > 1 ? 'DISTRIBUTE TIP' : 'SEND TIP',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }

  double get _currentTokenAmount {
    final input = double.tryParse(
      amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    if (input == null || _selectedToken == null) return 0.0;
    if (_isUsdInput) {
      final price = _selectedToken!.priceUsd ?? 0.0;
      return price > 0 ? input / price : 0.0;
    }
    return input;
  }

  String _formatTokenAmount(BigInt rawAmount, int decimals) {
    if (decimals == 0) return rawAmount.toString();
    final raw = rawAmount.toString().padLeft(decimals + 1, '0');
    final split = raw.length - decimals;
    final whole = raw.substring(0, split);
    final fraction = raw.substring(split).replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }

  Future<void> _handleSend(MessagingProvider provider, double? input) async {
    setState(() => isPreparing = true);
    try {
      final decimals = _selectedToken!.decimals ?? 18;
      final useIndividualAmounts = _differentAmounts && _canCustomizeAmounts;
      final tokenAmounts = useIndividualAmounts
          ? recipients.map((recipient) {
              final entered =
                  double.tryParse(
                    _recipientAmountControllers[recipient.id]?.text.trim() ??
                        '',
                  ) ??
                  0.0;
              if (entered <= 0) return 0.0;
              if (!_isUsdInput) return entered;
              final price = _selectedToken!.priceUsd?.toDouble() ?? 0.0;
              return price > 0 ? entered / price : 0.0;
            }).toList()
          : [_currentTokenAmount];

      if (tokenAmounts.any((amount) => amount <= 0)) {
        throw Exception('Enter a valid amount for every selected person');
      }

      final rawAmounts = tokenAmounts
          .map(
            (amount) =>
                _toRawAmount(amount.toStringAsFixed(decimals), decimals),
          )
          .toList();
      final rawAmountValues = rawAmounts.map(BigInt.parse).toList();
      final totalRequired = rawAmountValues.fold<BigInt>(
        BigInt.zero,
        (total, amount) => total + amount,
      );
      final myBalance =
          BigInt.tryParse(_selectedToken!.rawBalance) ?? BigInt.zero;

      if (totalRequired > myBalance) {
        throw Exception(
          'Insufficient balance. You need ${_formatTokenAmount(totalRequired, decimals)} ${_selectedToken!.symbol} in total, but only have ${_selectedToken!.balance}.',
        );
      }

      final sharedAmount = tokenAmounts.first;
      final confirmationText = useIndividualAmounts
          ? recipients
                .asMap()
                .entries
                .map((entry) {
                  final amount = tokenAmounts[entry.key]
                      .toStringAsFixed(6)
                      .replaceAll(RegExp(r'0+$'), '')
                      .replaceAll(RegExp(r'\.$'), '');
                  return '${entry.value.effectiveDisplayName}: $amount ${_selectedToken!.symbol}';
                })
                .join('\n')
          : 'Send ${sharedAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} ${_selectedToken!.symbol} to ${recipients.length} member${recipients.length > 1 ? "s" : ""}?';

      // Simple confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(recipients.length > 1 ? 'Distribute Batch' : 'Send Tip'),
          content: Text(confirmationText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => isPreparing = false);
        return;
      }

      Map<String, dynamic> prepared;
      if (recipients.length > 1) {
        prepared = await provider.prepareBatchTip(
          network: selectedNetwork!,
          recipients: recipients.map((r) => r.walletAddress).toList(),
          amounts: useIndividualAmounts
              ? rawAmounts
              : List.generate(recipients.length, (_) => rawAmounts.first),
          tokenAddress: _selectedToken!.isNative
              ? null
              : _selectedToken!.contractAddress,
        );
      } else {
        prepared = await provider.prepareTip(
          network: selectedNetwork!,
          recipient: recipients.first.walletAddress,
          amount: rawAmounts.first,
          tokenAddress: _selectedToken!.isNative
              ? null
              : _selectedToken!.contractAddress,
        );
      }

      await provider.executeTip(
        preparedTip: prepared,
        conversationId: widget.conversationId,
        tipMessage: useIndividualAmounts
            ? 'Sent individual ${_selectedToken!.symbol} tips to ${recipients.length} people'
            : recipients.length > 1
            ? 'Distributed ${sharedAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} ${_selectedToken!.symbol} each'
            : 'Tipped ${sharedAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} ${_selectedToken!.symbol}',
        onStatusUpdate: (s) {
          if (mounted) setState(() => _status = s);
        },
      );

      if (mounted) {
        context.read<WalletProvider>().loadWallet(force: true);
        Navigator.pop(context);
        NotificationService.showSuccess(context, 'Tip sent successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isPreparing = false);
        NotificationService.showError(context, 'Failed: $e');
      }
    }
  }

  String _toRawAmount(String input, int decimals) {
    if (input.isEmpty || input == '.') return '0';
    final cleanInput = input.replaceAll(',', '.');
    final parts = cleanInput.split('.');
    BigInt whole = BigInt.zero;
    try {
      if (parts[0].isNotEmpty) {
        whole = BigInt.parse(parts[0]);
      }
    } catch (_) {}
    BigInt fractional = BigInt.zero;
    if (parts.length > 1) {
      String fractionString = parts[1];
      if (fractionString.length > decimals) {
        fractionString = fractionString.substring(0, decimals);
      } else {
        fractionString = fractionString.padRight(decimals, '0');
      }
      try {
        fractional = BigInt.parse(fractionString);
      } catch (_) {}
    }
    return (whole * BigInt.from(10).pow(decimals) + fractional).toString();
  }

  Future<List<ChatUser>?> _showRecipientSelector(
    List<ChatUser> currentlySelected, {
    String? conversationId,
    ConversationType? type,
  }) async {
    if (conversationId == null && type == null) {
      final audience = await _showAudienceSelector();
      if (audience == null) return null;
      if (audience == _TipAudience.selectedPeople) {
        return _showGlobalRecipientSelector(currentlySelected);
      }
    }

    if (!mounted) return null;

    // This part remains largely the same logic-wise but could be optimized UI-wise
    final provider = context.read<MessagingProvider>();
    final currentUserId = context.read<UserProvider>().user?.id;
    List<ChatUser> allMembers;
    if (conversationId != null && type != null) {
      if (type == ConversationType.channel) {
        final rawMembers = await provider.getChannelMembers(conversationId);
        allMembers = rawMembers
            .map((m) => ChatUser.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } else {
        allMembers = await provider.getConversationMembers(
          conversationId,
          isGroup: type == ConversationType.group,
        );
      }
    } else {
      allMembers = provider.friends.map(ChatUser.fromUserModel).toList();
    }
    final seenAddresses = <String>{};
    final otherMembers = allMembers.where((m) {
      if (m.id == currentUserId ||
          m.walletAddress.isEmpty ||
          m.walletAddress == '0x') {
        return false;
      }
      if (seenAddresses.contains(m.walletAddress.toLowerCase())) {
        return false;
      }
      seenAddresses.add(m.walletAddress.toLowerCase());
      return true;
    }).toList();

    if (!mounted) return null;

    return await showModalBottomSheet<List<ChatUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<ChatUser> selected = List.from(currentlySelected);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = Theme.of(context).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          const Text(
                            'Select Recipients',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          if (selected.isNotEmpty)
                            TextButton(
                              onPressed: () =>
                                  setSheetState(() => selected.clear()),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: otherMembers.length,
                        itemBuilder: (context, index) {
                          final member = otherMembers[index];
                          final isSelected = selected.any(
                            (s) => s.id == member.id,
                          );
                          return ListTile(
                            onTap: () => setSheetState(
                              () => isSelected
                                  ? selected.removeWhere(
                                      (s) => s.id == member.id,
                                    )
                                  : selected.add(member),
                            ),
                            leading: CircleAvatar(
                              backgroundImage: member.profileUrl != null
                                  ? NetworkImage(member.profileUrl!)
                                  : null,
                            ),
                            title: Text(
                              member.effectiveDisplayName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? colors.primary
                                  : colors.outline,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child: Text('Confirm (${selected.length})'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_TipAudience?> _showAudienceSelector() {
    final colors = Theme.of(context).colorScheme;
    return showModalBottomSheet<_TipAudience>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Who would you like to tip?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose people before selecting the asset and amount.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Icon(Icons.people_alt_outlined, color: colors.primary),
              ),
              title: const Text(
                'Tip friends',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Choose from your friends list'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(sheetContext, _TipAudience.friends),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person_search_outlined,
                  color: colors.primary,
                ),
              ),
              title: const Text(
                'Tip selected people',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Search the global Griot user directory'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  Navigator.pop(sheetContext, _TipAudience.selectedPeople),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<ChatUser>?> _showGlobalRecipientSelector(
    List<ChatUser> currentlySelected,
  ) {
    final colors = Theme.of(context).colorScheme;
    final currentUserId = context.read<UserProvider>().user?.id;
    // The modal builder can rebuild when the keyboard opens or closes. Keep
    // selection and search state outside it so selected recipients survive
    // those layout rebuilds.
    final selected = List<ChatUser>.from(currentlySelected);
    List<ChatUser> results = [];
    Timer? debounce;
    var isLoading = false;
    String? errorMessage;
    var queryVersion = 0;
    final searchController = TextEditingController();

    return showModalBottomSheet<List<ChatUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> search(String query, StateSetter setSheetState) async {
          final trimmed = query.trim();
          final version = ++queryVersion;
          if (trimmed.length < 2) {
            setSheetState(() {
              results = [];
              isLoading = false;
              errorMessage = null;
            });
            return;
          }

          setSheetState(() {
            isLoading = true;
            errorMessage = null;
          });
          try {
            final response = await context
                .read<UserProvider>()
                .userApiService
                .searchUsers(trimmed, limit: 20);
            if (version != queryVersion || !mounted) return;
            final users = response['users'] as List? ?? const [];
            final seenIds = <String>{};
            setSheetState(() {
              results = users
                  .map<ChatUser?>((rawUser) {
                    if (rawUser is ChatUser) return rawUser;
                    if (rawUser is UserModel) {
                      return ChatUser.fromUserModel(rawUser);
                    }
                    if (rawUser is Map) {
                      return ChatUser.fromJson(
                        Map<String, dynamic>.from(rawUser),
                      );
                    }
                    return null;
                  })
                  .whereType<ChatUser>()
                  .where(
                    (user) =>
                        user.id != currentUserId &&
                        user.walletAddress.isNotEmpty &&
                        user.walletAddress != '0x',
                  )
                  .where((user) => seenIds.add(user.id))
                  .toList();
              isLoading = false;
            });
          } catch (_) {
            if (version == queryVersion && mounted) {
              setSheetState(() {
                results = [];
                isLoading = false;
                errorMessage =
                    'Search failed. Check your connection and try again.';
              });
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            builder: (context, scrollController) => GriotBottomSheet(
              radius: 28,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select people to tip',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search name, username, or wallet',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: colors.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            debounce?.cancel();
                            debounce = Timer(
                              const Duration(milliseconds: 350),
                              () {
                                search(value, setSheetState);
                              },
                            );
                          },
                        ),
                        if (selected.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${selected.length} selected',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selected.map((user) {
                                return InputChip(
                                  label: Text(user.effectiveDisplayName),
                                  onDeleted: () => setSheetState(
                                    () => selected.removeWhere(
                                      (item) => item.id == user.id,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: GriotLoader())
                        : results.isEmpty
                        ? Center(
                            child: Text(
                              errorMessage ??
                                  (searchController.text.trim().length < 2
                                      ? 'Type at least 2 characters to search.'
                                      : 'No eligible users found.'),
                              style: TextStyle(color: colors.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final user = results[index];
                              final isSelected = selected.any(
                                (item) => item.id == user.id,
                              );
                              return ListTile(
                                onTap: () => setSheetState(() {
                                  if (isSelected) {
                                    selected.removeWhere(
                                      (item) => item.id == user.id,
                                    );
                                  } else {
                                    selected.add(user);
                                  }
                                }),
                                leading: CircleAvatar(
                                  backgroundImage: user.profileUrl != null
                                      ? NetworkImage(user.profileUrl!)
                                      : null,
                                  child: user.profileUrl == null
                                      ? Text(
                                          user.effectiveDisplayName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  user.effectiveDisplayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: user.username == null
                                    ? null
                                    : Text('@${user.username}'),
                                trailing: Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? colors.primary
                                      : colors.outline,
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  debounce?.cancel();
                                  searchController.dispose();
                                  Navigator.pop(sheetContext, selected);
                                },
                          child: Text('Continue (${selected.length})'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<TokenModel?> _showTokenSelector(
    TokenModel? current,
    List<TokenModel> available,
  ) {
    final colors = Theme.of(context).colorScheme;
    return showModalBottomSheet<TokenModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Token',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No supported tokens found.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final token = available[index];
                    return ListTile(
                      onTap: () => Navigator.pop(context, token),
                      leading: CircleAvatar(
                        backgroundImage: token.imageUrl.isNotEmpty
                            ? NetworkImage(token.imageUrl)
                            : null,
                      ),
                      title: Text(
                        token.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${token.symbol} • ${token.balance}'),
                      trailing: token.identity == current?.identity
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactTipModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CompactTipModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: selected ? Colors.white : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
