import 'dart:convert';
import 'dart:io';

import 'package:jackbox_patcher/model/misc/launchers.dart';
import 'package:jackbox_patcher/model/usermodel/userjackboxpack.dart';
import 'package:jackbox_patcher/services/logger/logger.dart';
import 'package:win32_registry/win32_registry.dart';

/// This service is used to automatically find games installed on the user's computer
class AutomaticGameFinderService {
  /// This function will find games installed on the user's computer and link them to the packs
  static Future<int> findGames(List<UserJackboxPack> packs) async {
    for (UserJackboxPack pack in packs) {
      if (pack.origin == LauncherType.STEAM ||
          pack.origin == LauncherType.EPIC) {
        pack.origin = null;
        await pack.setOwned(false);
      }
    }
    try {
      int gameFound = 0;
      gameFound += await _findSteamGames(packs);
      gameFound += await _findEpicGamesGames(packs);
      return gameFound;
    } catch (e) {
      JULogger().e(e.toString());
      rethrow;
    }
  }

  static Future<int> _findSteamGames(List<UserJackboxPack> packs) async {
    int numberGamesFound = 0;
    String? steamLocation;
    if (Platform.isWindows) {
      steamLocation = _getSteamLocation();
    } else {
      steamLocation = Platform.environment["HOME"]! + "/.steam/steam";
    }
    if (steamLocation != null) {
      Map<String, List<String>> steamFolderWithAppId =
          _getSteamFoldersWithAppId(steamLocation);
      numberGamesFound =
          await _linkSteamFolderWithPack(steamFolderWithAppId, packs);
    }
    return numberGamesFound;
  }

  static Future<int> _findEpicGamesGames(List<UserJackboxPack> packs) async {
    int numberGamesFound = 0;
    if (Platform.isWindows) {
      final epicLocation = _getEpicLocation();
      if (epicLocation != null) {
        List<dynamic> epicApps = await _getEpicInstalledApps(epicLocation);
        print("Installed apps");
        numberGamesFound = await _linkEpicAppsWithPacks(epicApps, packs);
      }
    }
    return numberGamesFound;
  }

  static String? _getSteamLocation() {
    try {
      final key = Registry.openPath(RegistryHive.localMachine,
          path: 'SOFTWARE\\WOW6432Node\\Valve\\Steam');
      final steamLocation = key.getValueAsString("InstallPath");
      return steamLocation;
    } catch (e) {
      return null;
    }
  }

  static Map<String, List<String>> _getSteamFoldersWithAppId(
      String steamLocation) {
    Map<String, List<String>> folderWithApps = {};
    File file;
    if (Platform.isWindows) {
      file = File("$steamLocation\\steamapps\\libraryfolders.vdf");
    } else {
      file = File("$steamLocation/steamapps/libraryfolders.vdf");
    }
    final fileLines = file.readAsLinesSync();
    final pathLines = fileLines.where((element) => element.contains('"path"'));
    for (var line in pathLines) {
      List<String> thisFolderApps = fileLines
          .join("||")
          .split(line)[1]
          .split('"apps"')[1]
          .split("{")[1]
          .split("}")[0]
          .replaceAll("\t", "")
          .split('||')
          .where((element) => element.trim() != "")
          .map((e) => e.split('"')[1])
          .toList();
      folderWithApps[line.split('"')[3].replaceAll("\\\\", "\\")] =
          thisFolderApps;
      print(thisFolderApps);
    }
    return folderWithApps;
  }

  static _getSteamGamePathFromFolderAndAppId(String folder, String appId) {
    final file = File("$folder" +
        Platform.pathSeparator +
        "steamapps" +
        Platform.pathSeparator +
        "appmanifest_$appId.acf");
    final fileLines = file.readAsLinesSync();
    final pathLines =
        fileLines.where((element) => element.contains('"installdir"'));
    return "$folder" +
        Platform.pathSeparator +
        "steamapps" +
        Platform.pathSeparator +
        "common" +
        Platform.pathSeparator +
        "${pathLines.first.split('"')[3]}";
  }

  static Future<int> _linkSteamFolderWithPack(
      Map<String, List<String>> steamFoldersWithAppId,
      List<UserJackboxPack> userPacks) async {
    int numberGamesFound = 0;
    for (UserJackboxPack userPack in userPacks) {
      if (userPack.pack.launchersId != null &&
          userPack.pack.launchersId!.steam != null) {
        for (var folder in steamFoldersWithAppId.keys) {
          if (await File("$folder" +
                  Platform.pathSeparator +
                  "steamapps" +
                  Platform.pathSeparator +
                  "appmanifest_${userPack.pack.launchersId!.steam!}.acf")
              .exists()) {
            numberGamesFound++;
            await userPack.setOwned(true);
            await userPack.setPath(_getSteamGamePathFromFolderAndAppId(
                folder, userPack.pack.launchersId!.steam!));
            await userPack.setLauncher(LauncherType.STEAM);
          }
        }
      }
    }
    return numberGamesFound;
  }

  static String? _getEpicLocation() {
    print("Epic games location");
    try {
      final key = Registry.openPath(RegistryHive.localMachine,
          path: 'SOFTWARE\\WOW6432Node\\Epic Games\\EpicGamesLauncher');
      final epicLocation = key.getValueAsString("AppDataPath");
      return epicLocation;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> _getEpicInstalledApps(
      String epicLocation) async {
    print("Epic games apps");
    final file = File(
        "$epicLocation\\..\\..\\UnrealEngineLauncher\\LauncherInstalled.dat");
    print("File found");
    String fileData = await file.readAsString();
    print(fileData);
    List<dynamic> installationList =
        jsonDecode(fileData)["InstallationList"] as List<dynamic>;
    print(installationList);
    return installationList;
  }

  static Future<int> _linkEpicAppsWithPacks(
      List<dynamic> apps, List<UserJackboxPack> packs) async {
    int numberGamesFound = 0;
    print("Linking");
    for (UserJackboxPack userPack in packs) {
      if (userPack.pack.launchersId != null &&
          userPack.pack.launchersId!.epic != null) {
        for (var app in apps) {
          if (app["AppName"] == userPack.pack.launchersId!.epic) {
            numberGamesFound++;
            await userPack.setOwned(true);
            await userPack.setPath(app["InstallLocation"]!);
          }
        }
      }
    }
    return numberGamesFound;
  }
}
