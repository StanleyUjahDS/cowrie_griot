import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/messaging_provider.dart';
import '../../../../core/services/notification_service.dart';

class ReportContentSheet {
  ReportContentSheet._();

  static const _reasons = <String, String>{
    'spam': 'Spam',
    'harassment': 'Harassment or bullying',
    'hate_or_abuse': 'Hate or abusive content',
    'sexual_content': 'Sexual content',
    'violence_or_threat': 'Violence or threat',
    'scam_or_fraud': 'Scam or fraud',
    'self_harm': 'Self-harm concern',
    'other': 'Other',
  };

  static Future<void> show({
    required BuildContext context,
    required String targetType,
    required String targetId,
    required String subjectLabel,
  }) async {
    final detailsController = TextEditingController();
    var selectedReason = 'spam';
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = Theme.of(context).colorScheme;
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, color: colors.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Report $subjectLabel',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reports are reviewed by the Griot safety team. Select the reason that best describes the issue.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          RadioGroup<String>(
                            groupValue: selectedReason,
                            onChanged: (value) {
                              if (isSubmitting || value == null) return;
                              setSheetState(() => selectedReason = value);
                            },
                            child: Column(
                              children: _reasons.entries
                                  .map(
                                    (entry) => RadioListTile<String>(
                                      value: entry.key,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          TextField(
                            controller: detailsController,
                            maxLength: 1000,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Additional details (optional)',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await context
                                      .read<MessagingProvider>()
                                      .reportContent(
                                        targetType: targetType,
                                        targetId: targetId,
                                        reason: selectedReason,
                                        details: detailsController.text,
                                      );
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                  NotificationService.showSuccess(
                                    context,
                                    'Report submitted. Thank you for helping keep Griot safe.',
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                    NotificationService.showError(
                                      context,
                                      'Could not submit your report. Please try again.',
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.flag_rounded),
                        label: Text(isSubmitting ? 'Submitting...' : 'Submit report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    detailsController.dispose();
  }
}
