import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/link_launcher.dart';
import 'package:statussozo/utils/app_log.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URI in another app. Returns whether it was handled.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// [LinkLauncher] over `url_launcher`. It launches directly inside try/catch
/// rather than calling `canLaunchUrl`, which avoids package-visibility traps.
class UrlLinkLauncher implements LinkLauncher {
  UrlLinkLauncher({UrlOpener? opener}) : _opener = opener ?? _systemOpener;

  final UrlOpener _opener;

  static Future<bool> _systemOpener(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// A `mailto:` URI with an encoded subject and body.
  static Uri buildMailto({
    required String to,
    required String subject,
    required String body,
  }) {
    return Uri(
      scheme: 'mailto',
      path: to,
      query:
          'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
  }

  Future<bool> _safe(Uri uri) async {
    try {
      return await _opener(uri);
    } on Object catch (error) {
      AppLog.warn('links', 'could not open $uri', error);
      return false;
    }
  }

  @override
  Future<bool> openUrl(Uri uri) => _safe(uri);

  @override
  Future<bool> composeEmail({
    required String to,
    required String subject,
    required String body,
  }) => _safe(buildMailto(to: to, subject: subject, body: body));

  @override
  Future<bool> openStoreListing() async {
    final Uri market = Uri.parse(
      'market://details?id=${AppConfig.applicationId}',
    );
    if (await _safe(market)) {
      return true;
    }
    return _safe(Uri.parse(AppConfig.storeListingUrl));
  }
}
