import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// A group header: uppercase `sectionHeader` text in the tertiary colour,
/// announced as a header by screen readers.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.md,
          top: AppSpacing.lg,
          bottom: AppSpacing.sm,
        ),
        child: Text(label.toUpperCase(), style: styles.sectionHeader),
      ),
    );
  }
}
