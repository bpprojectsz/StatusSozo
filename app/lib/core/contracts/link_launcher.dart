/// Port for leaving the app. Every method returns whether it succeeded.
abstract interface class LinkLauncher {
  Future<bool> openUrl(Uri uri);

  Future<bool> composeEmail({
    required String to,
    required String subject,
    required String body,
  });

  Future<bool> openStoreListing();
}
