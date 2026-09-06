import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';

/// A horizontal row of filter chips.
class TierFilterRow extends StatelessWidget {
  const TierFilterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// (value, label). A null value means "all".
  final List<(String?, String)> options;
  final String? selected;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.sm),
        itemBuilder: (_, i) {
          final (value, label) = options[i];
          return ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          );
        },
      ),
    );
  }
}
