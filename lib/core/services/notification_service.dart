import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationService {
  static void showSuccess(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showSimpleNotification(
      Text(
        message,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      leading: Icon(Icons.check_circle_rounded, color: colorScheme.primary),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }

  static String _parseErrorMessage(String rawMessage) {
    var msg = rawMessage.trim();

    // Remove common prefixes
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring(11);
    }
    if (msg.startsWith('Transaction failed: ')) {
      msg = msg.substring(20);
    }
    if (msg.startsWith('Swap failed: ')) {
      msg = msg.substring(13);
    }

    final lower = msg.toLowerCase();

    // 1. Insufficient Funds / Gas
    if (lower.contains('insufficient funds') || lower.contains('insufficient_funds')) {
      if (lower.contains('gas') || lower.contains('transfer') || lower.contains('fee')) {
        return "Insufficient funds to cover transaction value and network gas fees. Please deposit some native gas tokens (e.g. BNB or ETH) first.";
      }
      return "Insufficient funds in your wallet to complete this transaction.";
    }

    // 2. Insufficient Token Balance
    if (lower.contains('insufficient token balance') || lower.contains('insufficient balance')) {
      return "Insufficient balance: You don't have enough of this token to complete this transfer.";
    }

    // 3. User Rejected / Canceled
    if (lower.contains('user rejected') || lower.contains('canceled') || lower.contains('cancelled')) {
      return "Transaction was canceled.";
    }

    // 4. Overly long JSON/RPC strings
    if (lower.contains('transaction=') || lower.contains('code=') || lower.contains('version=')) {
      // Attempt to extract the inner message inside "message: ..."
      final regExp = RegExp(r'"message"\s*:\s*"([^"]+)"');
      final match = regExp.firstMatch(msg);
      if (match != null && match.groupCount >= 1) {
        final rpcMessage = match.group(1);
        if (rpcMessage != null && rpcMessage.isNotEmpty) {
          return _parseErrorMessage(rpcMessage); // Recurse on the extracted message
        }
      }
      
      if (lower.contains('insufficient funds')) {
        return "Insufficient funds to cover transaction value and network gas fees.";
      }
      
      return "Blockchain Node Error: The transaction failed to estimate gas. This usually indicates insufficient native gas balance or a contract execution failure.";
    }

    return msg;
  }

  static void showError(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parsedMessage = _parseErrorMessage(message);

    showSimpleNotification(
      Text(
        parsedMessage,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          fontSize: 13,
        ),
      ),
      leading: Icon(Icons.error_outline_rounded, color: colorScheme.error),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 5),
      position: NotificationPosition.top,
    );
  }

  static void showInfo(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showSimpleNotification(
      Text(
        message,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      leading: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }
}
