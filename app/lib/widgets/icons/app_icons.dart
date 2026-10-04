import 'package:hugeicons/hugeicons.dart';

/// Icon data as the icon package represents it.
typedef AppIconData = List<List<dynamic>>;

/// The only file that names underlying icon symbols. Screens and widgets use
/// these semantic aliases and never reach for the package directly.
abstract final class AppIcons {
  static const AppIconData close = HugeIcons.strokeRoundedCancel01;
  static const AppIconData back = HugeIcons.strokeRoundedArrowLeft01;
  static const AppIconData chevronForward = HugeIcons.strokeRoundedArrowRight01;
  static const AppIconData check = HugeIcons.strokeRoundedTick02;
  static const AppIconData checkCircle =
      HugeIcons.strokeRoundedCheckmarkCircle02;
  static const AppIconData save = HugeIcons.strokeRoundedDownload01;
  static const AppIconData share = HugeIcons.strokeRoundedShare01;
  static const AppIconData delete = HugeIcons.strokeRoundedDelete02;
  static const AppIconData play = HugeIcons.strokeRoundedPlay;
  static const AppIconData pause = HugeIcons.strokeRoundedPause;
  static const AppIconData replay = HugeIcons.strokeRoundedReload;
  static const AppIconData video = HugeIcons.strokeRoundedVideo01;
  static const AppIconData image = HugeIcons.strokeRoundedImage01;
  static const AppIconData folder = HugeIcons.strokeRoundedFolder01;
  static const AppIconData folderLink = HugeIcons.strokeRoundedFolderLinks;
  static const AppIconData settings = HugeIcons.strokeRoundedSettings01;
  static const AppIconData saved = HugeIcons.strokeRoundedAlbum02;
  static const AppIconData theme = HugeIcons.strokeRoundedMoon02;
  static const AppIconData help = HugeIcons.strokeRoundedHelpCircle;
  static const AppIconData rate = HugeIcons.strokeRoundedStar;
  static const AppIconData mail = HugeIcons.strokeRoundedMail01;
  static const AppIconData privacy = HugeIcons.strokeRoundedShield01;
  static const AppIconData info = HugeIcons.strokeRoundedInformationCircle;
  static const AppIconData refresh = HugeIcons.strokeRoundedRefresh;
  static const AppIconData warning = HugeIcons.strokeRoundedAlert02;
  static const AppIconData error = HugeIcons.strokeRoundedAlertCircle;
  static const AppIconData language = HugeIcons.strokeRoundedGlobe;
  static const AppIconData pro = HugeIcons.strokeRoundedCrown;
}
