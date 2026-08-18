import 'package:flutter/material.dart';

import '../models/message_request.dart';

class MessageRequestCard extends StatelessWidget {
  final MessageRequest request;

  final VoidCallback onAccept;

  final VoidCallback onDecline;

  const MessageRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final textTheme =
        theme.textTheme;

    final profileUrl =
        request.senderProfileUrl;

    final hasProfileImage =
        profileUrl != null &&
            profileUrl.trim().isNotEmpty;

    return Container(
      padding:
      const EdgeInsets.all(15),

      decoration:
      BoxDecoration(
        color: colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.45,
        ),

        borderRadius:
        BorderRadius.circular(18),

        border: Border.all(
          color: colorScheme.outline
              .withValues(
            alpha: 0.14,
          ),
        ),
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          // ====================================================
          // USER INFORMATION
          // ====================================================

          Row(
            children: [
              CircleAvatar(
                radius: 27,

                backgroundColor:
                colorScheme
                    .surfaceContainerHighest,

                backgroundImage:
                hasProfileImage
                    ? NetworkImage(
                  profileUrl,
                )
                    : null,

                child:
                !hasProfileImage
                    ? Icon(
                  Icons
                      .person_rounded,
                  color: colorScheme
                      .onSurfaceVariant,
                )
                    : null,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    // ==========================================
                    // DISPLAY NAME
                    // ==========================================

                    Text(
                      request.displayName,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,

                      style: textTheme
                          .bodyLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    // ==========================================
                    // USERNAME / WALLET
                    // ==========================================

                    if (request
                        .formattedUsername !=
                        null)
                      Text(
                        request
                            .formattedUsername!,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                          colorScheme
                              .primary,
                        ),
                      )
                    else
                      Text(
                        request
                            .shortWalletAddress,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // ==============================================
              // ONLINE STATUS
              // ==============================================

              if (request.senderIsOnline)
                Container(
                  width: 8,
                  height: 8,

                  decoration:
                  const BoxDecoration(
                    color:
                    Color(0xFF22C55E),
                    shape:
                    BoxShape.circle,
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          // ==================================================
          // REQUEST MESSAGE
          // ==================================================

          if (request.message
              .trim()
              .isNotEmpty)
            Text(
              request.message,
              style: textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
                height: 1.4,
              ),
            ),

          if (request.message
              .trim()
              .isNotEmpty)
            const SizedBox(
              height: 14,
            ),

          // ==================================================
          // ACTION BUTTONS
          // ==================================================

          Row(
            children: [
              Expanded(
                child:
                OutlinedButton(
                  onPressed:
                  onDecline,
                  child:
                  const Text(
                    'Decline',
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                ElevatedButton(
                  onPressed:
                  onAccept,
                  child:
                  const Text(
                    'Accept',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}