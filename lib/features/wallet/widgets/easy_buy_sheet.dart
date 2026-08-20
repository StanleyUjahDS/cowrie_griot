import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void openEasyBuySheet(BuildContext context) {
  final TextEditingController messageController =
  TextEditingController();

  String detectedAddress = "";

  bool hasUserMessage = false;
  bool isDetected = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModal) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final text = theme.textTheme;

          void detectAddress() {
            final raw = messageController.text.trim();

            if (raw.isEmpty) {
              return;
            }

            final evmRegex = RegExp(
              r'0x[a-fA-F0-9]{40}',
            );

            final solanaRegex = RegExp(
              r'\b[1-9A-HJ-NP-Za-km-z]{32,44}\b',
            );

            final evmMatch = evmRegex.firstMatch(raw);
            final solanaMatch = solanaRegex.firstMatch(raw);

            if (evmMatch != null) {
              detectedAddress = evmMatch.group(0)!;
              isDetected = true;
            } else if (solanaMatch != null) {
              detectedAddress = solanaMatch.group(0)!;
              isDetected = true;
            } else {
              detectedAddress = "";
              isDetected = false;
            }

            hasUserMessage = true;

            setModal(() {});
          }

          Future<void> pasteFromClipboard() async {
            final clipboard = await Clipboard.getData(
              Clipboard.kTextPlain,
            );

            if (clipboard?.text == null) {
              return;
            }

            final value = clipboard!.text!.trim();

            if (value.isEmpty) {
              return;
            }

            messageController.text = value;

            setModal(() {});
          }

          Future<void> copyAddress() async {
            if (detectedAddress.isEmpty) {
              return;
            }

            await Clipboard.setData(
              ClipboardData(
                text: detectedAddress,
              ),
            );
          }

          Widget actionButton({
            required IconData icon,
            required String label,
            required VoidCallback onTap,
            bool primary = false,
          }) {
            return Expanded(
              child: SizedBox(
                height: 46,
                child: primary
                    ? ElevatedButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    icon,
                    size: 18,
                  ),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    : OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(
                    icon,
                    size: 18,
                  ),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }

          Widget detectedTokenCard() {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 23,
                        backgroundColor:
                        colors.primary.withValues(alpha: 0.10),
                        child: Icon(
                          Icons.token_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Address detected",
                              style: text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Waiting for token information...",
                              style: text.bodySmall?.copyWith(
                                color:
                                colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            detectedAddress,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              fontFamily: "monospace",
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          borderRadius:
                          BorderRadius.circular(8),
                          onTap: copyAddress,
                          child: Padding(
                            padding:
                            const EdgeInsets.all(5),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 17,
                              color:
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 18,
                          color:
                          colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Token information will appear here.",
                            style:
                            text.bodySmall?.copyWith(
                              color:
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      actionButton(
                        icon:
                        Icons.shopping_cart_rounded,
                        label: "Buy",
                        primary: true,
                        onTap: () {
                          debugPrint(
                            "BUY $detectedAddress",
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      actionButton(
                        icon: Icons.sell_rounded,
                        label: "Sell",
                        onTap: () {
                          debugPrint(
                            "SELL $detectedAddress",
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      actionButton(
                        icon:
                        Icons.show_chart_rounded,
                        label: "Chart",
                        onTap: () {
                          debugPrint(
                            "CHART $detectedAddress",
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      actionButton(
                        icon:
                        Icons.open_in_new_rounded,
                        label: "View",
                        onTap: () {
                          debugPrint(
                            "VIEW $detectedAddress",
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget unsupportedAddressCard() {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest
                    .withValues(alpha: 0.55),
                borderRadius:
                const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 20,
                    color: colors.error,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "I couldn't find a supported wallet or "
                          "contract address in that message.",
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.90,
            maxChildSize: 0.97,
            minChildSize: 0.65,
            expand: false,
            builder: (_, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius:
                  const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 5,
                            decoration:
                            BoxDecoration(
                              color: colors.onSurface
                                  .withValues(alpha: 0.18),
                              borderRadius:
                              BorderRadius.circular(
                                20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                colors.primary
                                    .withValues(alpha: 0.10),
                                child: Icon(
                                  Icons
                                      .flash_on_rounded,
                                  color:
                                  colors.primary,
                                ),
                              ),
                              const SizedBox(
                                  width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                                  children: [
                                    Text(
                                      "Easy Buy",
                                      style: text
                                          .titleMedium
                                          ?.copyWith(
                                        fontWeight:
                                        FontWeight
                                            .w700,
                                      ),
                                    ),
                                    Text(
                                      "Token trading assistant",
                                      style: text
                                          .bodySmall
                                          ?.copyWith(
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: Colors.green
                                      .withValues(alpha: 0.10),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    20,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize:
                                  MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration:
                                      const BoxDecoration(
                                        color:
                                        Colors.green,
                                        shape: BoxShape
                                            .circle,
                                      ),
                                    ),
                                    const SizedBox(
                                        width: 5),
                                    Text(
                                      "Online",
                                      style: text
                                          .labelSmall
                                          ?.copyWith(
                                        color:
                                        Colors.green,
                                        fontWeight:
                                        FontWeight
                                            .w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color:
                      colors.outline.withValues(alpha: 0.10),
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        padding:
                        const EdgeInsets.fromLTRB(
                          14,
                          18,
                          14,
                          12,
                        ),
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                colors.primary
                                    .withValues(alpha: 0.10),
                                child: Icon(
                                  Icons
                                      .flash_on_rounded,
                                  size: 18,
                                  color:
                                  colors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration:
                                  BoxDecoration(
                                    color: colors
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                                    borderRadius:
                                    const BorderRadius
                                        .only(
                                      topLeft:
                                      Radius.circular(
                                          18),
                                      topRight:
                                      Radius.circular(
                                          18),
                                      bottomRight:
                                      Radius.circular(
                                          18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        "Easy Buy",
                                        style: text
                                            .labelSmall
                                            ?.copyWith(
                                          color: colors
                                              .primary,
                                          fontWeight:
                                          FontWeight
                                              .w700,
                                        ),
                                      ),
                                      const SizedBox(
                                          height: 4),
                                      Text(
                                        "Send me a contract address, "
                                            "wallet address, or any text "
                                            "containing one.",
                                        style:
                                        text.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (hasUserMessage) ...[
                            Align(
                              alignment:
                              Alignment.centerRight,
                              child: Container(
                                constraints:
                                const BoxConstraints(
                                  maxWidth: 310,
                                ),
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration:
                                BoxDecoration(
                                  color:
                                  colors.primary,
                                  borderRadius:
                                  const BorderRadius
                                      .only(
                                    topLeft:
                                    Radius.circular(
                                        18),
                                    topRight:
                                    Radius.circular(
                                        18),
                                    bottomLeft:
                                    Radius.circular(
                                        18),
                                    bottomRight:
                                    Radius.circular(
                                        4),
                                  ),
                                ),
                                child: Text(
                                  messageController.text,
                                  style: text
                                      .bodyMedium
                                      ?.copyWith(
                                    color:
                                    colors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                  colors.primary
                                      .withValues(alpha: 0.10),
                                  child: Icon(
                                    Icons
                                        .flash_on_rounded,
                                    size: 18,
                                    color:
                                    colors.primary,
                                  ),
                                ),
                                const SizedBox(
                                    width: 8),
                                Flexible(
                                  child: isDetected
                                      ? detectedTokenCard()
                                      : unsupportedAddressCard(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding:
                        const EdgeInsets.fromLTRB(
                          10,
                          8,
                          10,
                          10,
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration:
                                BoxDecoration(
                                  color: colors
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    24,
                                  ),
                                  border: Border.all(
                                    color: colors
                                        .outline
                                        .withValues(alpha: 0.10),
                                  ),
                                ),
                                child: TextField(
                                  controller:
                                  messageController,
                                  minLines: 1,
                                  maxLines: 5,
                                  decoration:
                                  InputDecoration(
                                    hintText:
                                    "Message Easy Buy...",
                                    border:
                                    InputBorder.none,
                                    contentPadding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    prefixIcon:
                                    Icon(
                                      Icons
                                          .attach_file_rounded,
                                      color: colors
                                          .onSurfaceVariant,
                                    ),
                                    suffixIcon:
                                    IconButton(
                                      tooltip: "Paste",
                                      icon: Icon(
                                        Icons
                                            .content_paste_rounded,
                                        color: colors
                                            .onSurfaceVariant,
                                      ),
                                      onPressed:
                                      pasteFromClipboard,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: colors.primary,
                              shape:
                              const CircleBorder(),
                              child: InkWell(
                                customBorder:
                                const CircleBorder(),
                                onTap: detectAddress,
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    Icons
                                        .arrow_upward_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}