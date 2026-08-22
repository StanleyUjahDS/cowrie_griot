import 'package:flutter/material.dart';
import '../models/token_model.dart';
import 'token_list_item.dart';

class TokenList extends StatelessWidget {
  final List<TokenModel> tokens;
  final Widget emptyState;
  final Function(TokenModel) onTokenTap;
  final Function(TokenModel)? onTokenLongPress;

  const TokenList({
    super.key,
    required this.tokens,
    required this.emptyState,
    required this.onTokenTap,
    this.onTokenLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) {
      return emptyState;
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final token = tokens[index];
          return TokenListItem(
            token: token,
            onTap: () => onTokenTap(token),
            onLongPress: onTokenLongPress == null ? null : () => onTokenLongPress!(token),
          );
        },
        childCount: tokens.length,
      ),
    );
  }
}
