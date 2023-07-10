import 'package:jackbox_patcher/model/jackbox/jackboxpackpatch.dart';
import 'package:jackbox_patcher/model/usermodel/userjackboxgamepatch.dart';
import 'package:jackbox_patcher/model/usermodel/userjackboxpack.dart';

import '../../services/downloader/downloader_service.dart';
import '../../services/user/userdata.dart';

class UserJackboxPackPatch {
  final JackboxPackPatch patch;
  String? installedVersion;

  UserJackboxPackPatch({
    required this.patch,
    required this.installedVersion,
  });

  UserInstalledPatchStatus getInstalledStatus() {
    UserJackboxPack pack = getPack();
    String? packPath = pack.path;
    bool owned = pack.owned;
    if (patch.latestVersion != "" &&
        packPath != null &&
        packPath != "" &&
        owned) {
      if (installedVersion != null && installedVersion != "") {
        if (installedVersion == patch.latestVersion) {
          return UserInstalledPatchStatus.INSTALLED;
        } else {
          if (installedVersion!.split("-").length > 1 &&
              installedVersion!.split("-")[1] ==
                  patch.latestVersion.split("-")[1]) {
            return UserInstalledPatchStatus.INSTALLED_OUTDATED;
          } else {
            return UserInstalledPatchStatus.NOT_INSTALLED;
          }
        }
      } else {
        return UserInstalledPatchStatus.NOT_INSTALLED;
      }
    } else {
      print("INEXISTANT");
      return UserInstalledPatchStatus.INEXISTANT;
    }
  }

  Future<void> downloadPatch(
      String patchUri, void Function(String, String, double) callback) async {
    await DownloaderService.downloadPatch(patchUri, patch.patchPath, callback);
    installedVersion = patch.latestVersion;
  }

  UserJackboxPack getPack() {
    List<UserJackboxPack> dataFound = UserData()
        .packs
        .where((pack) => pack.patches
            .where((element) => element.patch.id == patch.id)
            .isNotEmpty)
        .toList();
    if (dataFound.length > 0) {
      return dataFound[0];
    } else {
      return UserData().packs.firstWhere((pack) => pack.fixes
          .where((element) => element.patch.id == patch.id)
          .isNotEmpty);
    }
  }
}
