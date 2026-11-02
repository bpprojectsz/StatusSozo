import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/utils/license_collector.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/app_row.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';

/// The open-source licenses: every package that ships with the app.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  final Future<List<PackageLicense>> _licenses = collectLicenses();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ScreenScaffold(
      navBar: AppNavBar.pushed(
        title: l10n.licensesTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: FutureBuilder<List<PackageLicense>>(
        future: _licenses,
        builder: (BuildContext context, AsyncSnapshot<List<PackageLicense>> s) {
          final List<PackageLicense>? data = s.data;
          if (data == null && !s.hasError) {
            return const Center(child: AppLoadingIndicator());
          }
          if (data == null || data.isEmpty) {
            return EmptyState(
              icon: AppIcons.licenses,
              title: l10n.licensesEmptyTitle,
            );
          }
          return ScrollConfiguration(
            behavior: const AppScrollBehavior(),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.gutter,
                end: AppSpacing.gutter,
                bottom: AppSpacing.xl,
              ),
              children: <Widget>[
                AppGroup(
                  dividerInset: AppSpacing.md,
                  children: <Widget>[
                    for (final PackageLicense license in data)
                      AppRow(
                        label: license.name,
                        showChevron: true,
                        onPressed: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => LicenseDetailScreen(license),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The full license text of one package.
class LicenseDetailScreen extends StatelessWidget {
  const LicenseDetailScreen(this.license, {super.key});

  final PackageLicense license;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    return ScreenScaffold(
      navBar: AppNavBar.pushed(
        title: license.name,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ScrollConfiguration(
        behavior: const AppScrollBehavior(),
        child: ListView.builder(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.gutter,
            end: AppSpacing.gutter,
            bottom: AppSpacing.xl,
          ),
          itemCount: license.paragraphs.length,
          itemBuilder: (BuildContext context, int index) {
            final LicenseParagraph paragraph = license.paragraphs[index];
            if (paragraph.text.isEmpty) {
              return const SizedBox(height: AppSpacing.md);
            }
            final bool centered =
                paragraph.indent == LicenseParagraph.centeredIndent;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                start: centered ? 0 : paragraph.indent * AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                paragraph.text,
                style: styles.footnote,
                textAlign: centered ? TextAlign.center : TextAlign.start,
              ),
            );
          },
        ),
      ),
    );
  }
}
