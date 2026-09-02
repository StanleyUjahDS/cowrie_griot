import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../users/providers/user_provider.dart';
import '../../../wallet/models/token_model.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../models/chat_user.dart';
import '../../models/conversation_model.dart';
import '../../providers/messaging_provider.dart';

class TipSheet extends StatefulWidget {
  final List<ChatUser> initialRecipients;
  final String? conversationId;
  final ConversationType? conversationType;

  const TipSheet({
    super.key,
    required this.initialRecipients,
    this.conversationId,
    this.conversationType,
  });

  static void show(
    BuildContext context, {
    required List<ChatUser> recipients,
    String? conversationId,
    ConversationType? conversationType,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TipSheet(
        initialRecipients: recipients,
        conversationId: conversationId,
        conversationType: conversationType,
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
  bool isPreparing = false;
  late List<ChatUser> recipients;

  // The selected token is the single source of truth for the network.
  String? get selectedNetwork {
    final network = _selectedToken?.rawNetwork.trim().toLowerCase();
    switch (network) {
      case 'bnb':
      case 'binance-smart-chain':
      case 'binance smart chain':
        return 'bsc';
      default:
        return network;
    }
  }

  @override
  void initState() {
    super.initState();
    recipients = List.from(widget.initialRecipients);

    final provider = context.read<MessagingProvider>();

    if (provider.tipConfig == null) {
      provider.loadTipConfig().then((_) {
        if (mounted) {
          _initDefaultToken();
        }
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
    if (provider.tipConfig == null) {
      return [];
    }
    final supportedNetworks = (provider.tipConfig!['networks'] as List)
        .map((n) => n['network'].toString().toLowerCase())
        .toSet();

    return wallet.tokens.where((t) {
      final balance = BigInt.tryParse(t.rawBalance) ?? BigInt.zero;
      final hasBalance = balance > BigInt.zero;
      final hasDecimals = t.decimals != null && t.decimals! > 0;
      final isSupported = supportedNetworks.contains(
        t.rawNetwork.toLowerCase(),
      );

      final isLegit = t.isOfficial || t.isEcosystem || t.hasMarketData;

      return hasBalance && hasDecimals && isSupported && isLegit;
    }).toList();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
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
    final tokenAmount = input == null || _selectedToken == null
        ? 0.0
        : (_isUsdInput ? input / (_selectedToken!.priceUsd ?? 1.0) : input);
    final usdValue = tokenAmount * (_selectedToken?.priceUsd ?? 0.0);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 35,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SvgPicture.asset(
                    'assets/cowrie_images/cowriesvg.svg',
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recipients.length > 1
                      ? 'Batch Tip Members'
                      : 'Tip ${recipients.firstOrNull?.effectiveDisplayName ?? "User"}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recipients.length > 1
                      ? 'Sending to ${recipients.length} people'
                      : 'Send crypto directly to this user',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                if (widget.conversationType != null &&
                    widget.conversationType != ConversationType.dm)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      onTap: () async {
                        final selected = await _showRecipientSelector(
                          recipients,
                          widget.conversationId!,
                          widget.conversationType!,
                        );
                        if (selected != null) {
                          setState(() {
                            recipients = selected;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_add_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                recipients.isEmpty
                                    ? 'Select recipients'
                                    : '${recipients.length} selected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (selectedNetwork != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lan_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Network: ${selectedNetwork!.toUpperCase()}',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    final selected = await _showTokenSelector(
                      _selectedToken,
                      availableTokens,
                    );
                    if (selected != null) {
                      setState(() {
                        _selectedToken = selected;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          child:
                              _selectedToken?.imageUrl != null &&
                                  _selectedToken!.imageUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _selectedToken!.imageUrl,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _selectedToken?.symbol.substring(0, 1) ??
                                        '?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedToken?.name ?? 'Select Token',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedToken?.symbol ?? ""} • \$${(_selectedToken?.priceUsd ?? 0.0).toStringAsFixed(4)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TipModeButton(
                          label: _selectedToken?.symbol ?? "Token",
                          selected: !_isUsdInput,
                          onTap: () {
                            setState(() {
                              _isUsdInput = false;
                              amountController.clear();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _TipModeButton(
                          label: 'USD',
                          selected: _isUsdInput,
                          onTap: () {
                            setState(() {
                              _isUsdInput = true;
                              amountController.clear();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isUsdInput)
                        Text(
                          '\$',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            hintStyle: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_isUsdInput)
                        Text(
                          _selectedToken?.symbol ?? "",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (input != null && input > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isUsdInput
                              ? '${tokenAmount.toStringAsFixed(6)} ${_selectedToken?.symbol ?? ""}'
                              : '\$${usdValue.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isUsdInput
                              ? 'Estimated token amount'
                              : 'Estimated USD value',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed:
                        amountController.text.isEmpty ||
                            isPreparing ||
                            recipients.isEmpty ||
                            _selectedToken == null
                        ? null
                        : () async {
                            setState(() => isPreparing = true);
                            try {
                              if (recipients.length > 200) {
                                throw Exception(
                                  'Maximum batch size is 200 recipients',
                                );
                              }

                              final rawAmount = _toRawAmount(
                                amountController.text,
                                _selectedToken!.decimals ?? 18,
                              );

                              Map<String, dynamic> prepared;
                              if (recipients.length > 1) {
                                prepared = await provider.prepareBatchTip(
                                  network: selectedNetwork!,
                                  recipients: recipients
                                      .map((r) => r.walletAddress)
                                      .toList(),
                                  amounts: List.generate(
                                    recipients.length,
                                    (_) => rawAmount,
                                  ),
                                  tokenAddress: _selectedToken!.isNative
                                      ? null
                                      : _selectedToken!.contractAddress,
                                );
                              } else {
                                prepared = await provider.prepareTip(
                                  network: selectedNetwork!,
                                  recipient: recipients.first.walletAddress,
                                  amount: rawAmount,
                                  tokenAddress: _selectedToken!.isNative
                                      ? null
                                      : _selectedToken!.contractAddress,
                                );
                              }

                              final preparedNetwork = provider
                                  .normalizeNetworkName(
                                    prepared['network']?.toString(),
                                  );
                              final currentNetwork = provider
                                  .normalizeNetworkName(selectedNetwork);

                              if (preparedNetwork != currentNetwork) {
                                throw Exception(
                                  'Network mismatch: selected $currentNetwork, prepared $preparedNetwork',
                                );
                              }

                              final hash = await provider.executeTip(
                                preparedTip: prepared,
                                onStatusUpdate: (s) {
                                  if (mounted) {
                                    setState(() => isPreparing = true);
                                  }
                                },
                              );

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.of(context).pop();
                              NotificationService.showSuccess(
                                context,
                                'Tip confirmed! Hash: ${hash.substring(0, 10)}...',
                              );
                            } catch (e) {
                              if (!context.mounted) {
                                return;
                              }
                              setState(() => isPreparing = false);
                              NotificationService.showError(
                                context,
                                'Tip failed: $e',
                              );
                            }
                          },
                    icon: isPreparing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bolt_rounded),
                    label: Text(isPreparing ? 'Processing...' : 'Send Tip Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _toRawAmount(String input, int decimals) {
    final cleanInput = input.replaceAll(',', '.');
    final parts = cleanInput.split('.');

    BigInt whole = BigInt.parse(parts[0]);
    BigInt fractional = BigInt.zero;

    if (parts.length > 1) {
      String fractionString = parts[1];
      if (fractionString.length > decimals) {
        fractionString = fractionString.substring(0, decimals);
      } else {
        fractionString = fractionString.padRight(decimals, '0');
      }
      fractional = BigInt.parse(fractionString);
    }

    final BigInt multiplier = BigInt.from(10).pow(decimals);
    return (whole * multiplier + fractional).toString();
  }

  Future<List<ChatUser>?> _showRecipientSelector(
    List<ChatUser> currentlySelected,
    String conversationId,
    ConversationType type,
  ) async {
    final provider = context.read<MessagingProvider>();
    final currentUserId = context.read<UserProvider>().user?.id;

    final List<ChatUser> allMembers = await provider.getConversationMembers(
      conversationId,
      isGroup: type == ConversationType.group,
    );

    if (!mounted) {
      return null;
    }

    final otherMembers = allMembers
        .where((m) => m.id != currentUserId)
        .toList();

    if (!mounted) {
      return null;
    }

    return await showModalBottomSheet<List<ChatUser>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<ChatUser> selected = List.from(currentlySelected);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(30),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Select Recipients',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: otherMembers.length,
                      itemBuilder: (context, index) {
                        final member = otherMembers[index];
                        final isSelected = selected.any(
                          (s) => s.id == member.id,
                        );
                        return ListTile(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selected.removeWhere((s) => s.id == member.id);
                              } else {
                                selected.add(member);
                              }
                            });
                          },
                          leading: CircleAvatar(
                            backgroundImage: member.profileUrl != null
                                ? NetworkImage(member.profileUrl!)
                                : null,
                            child: member.profileUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            member.effectiveDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (_) {
                              setSheetState(() {
                                if (isSelected) {
                                  selected.removeWhere(
                                    (s) => s.id == member.id,
                                  );
                                } else {
                                  selected.add(member);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: Text('Confirm (${selected.length})'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<TokenModel?> _showTokenSelector(
    TokenModel? current,
    List<TokenModel> available,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<TokenModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select token from your wallet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No supported tokens found in your wallet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final token = available[index];
                    final selected = token.identity == current?.identity;
                    return ListTile(
                      onTap: () => Navigator.pop(context, token),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.08),
                        ),
                        child: token.imageUrl.isNotEmpty
                            ? ClipOval(child: Image.network(token.imageUrl))
                            : Center(
                                child: Text(
                                  token.symbol.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                      ),
                      title: Text(
                        token.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${token.symbol} • ${token.balance} • ${token.chain.toUpperCase()}',
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
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

class _TipModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TipModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
