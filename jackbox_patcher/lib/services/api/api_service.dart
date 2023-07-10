import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:http/http.dart' as http;
import 'package:jackbox_patcher/model/jackbox/jackboxgame.dart';
import 'package:jackbox_patcher/model/jackbox/jackboxpackpatch.dart';
import 'package:jackbox_patcher/model/misc/urlblurhash.dart';
import 'package:jackbox_patcher/model/news.dart';
import 'package:jackbox_patcher/model/patchServerConfigurations.dart';
import 'package:jackbox_patcher/model/patchserver.dart';
import 'package:jackbox_patcher/services/logger/logger.dart';

import '../../model/gametag.dart';
import '../../model/jackbox/jackboxpack.dart';
import '../../model/patchsCategory.dart';
import 'api_endpoints.dart';

class APIService {
  static final APIService _instance = APIService._internal();
  String masterServer = FlavorConfig.instance.variables["masterServerUrl"];
  String? baseEndpoint;
  String? baseAssets;

  List<PatchServer> cachedServers = [];
  PatchServer? cachedSelectedServer;
  List<JackboxPack> cachedPacks = [];
  List<GameTag> cachedTags = [];
  List<PatchCategory> cachedCategories = [];
  List<News> cachedNews = [];
  List<UrlBlurHash> cachedBlurHashes = [];
  PatchServerConfigurations? cachedConfigurations;

  factory APIService() {
    return _instance;
  }

  // Build internal
  APIService._internal();

  void resetCache() {
    JULogger().i("Resetting cache");
    cachedServers = [];
    cachedPacks = [];
    cachedTags = [];
    cachedNews = [];
  }

  Future<void> recoverAvailableServers() async {
    JULogger().i("Recovering available servers");
    resetCache();
    final data = await getRequest(Uri.parse(masterServer));
    final List<dynamic> availableServers = jsonDecode(data);
    for (var server in availableServers) {
      final serverInfo = await getRequest(Uri.parse(server));
      final Map<String, dynamic> data = jsonDecode(serverInfo);
      cachedServers.add(PatchServer.fromJson(server, data));
    }
  }

  Future<void> recoverServerInfo(String serverLink) async {
    JULogger().i("Recovering server info");
    final rawData = await getRequest(Uri.parse(serverLink));
    final Map<String, dynamic> data = jsonDecode(rawData);
    cachedSelectedServer = PatchServer.fromJson(serverLink, data);
    final endpoints = await cachedSelectedServer!.getVersionUrl();
    baseEndpoint = endpoints.apiEndpoint;
    baseAssets = endpoints.assetsEndpoint;
  }

  Future<void> recoverPacksAndTags() async {
    final rawData =
        await getRequest(Uri.parse('$baseEndpoint${APIEndpoints.PACKS.path}'));
    final Map<String, dynamic> data = jsonDecode(rawData);
    cachedTags =
        data["tags"].map<GameTag>((tag) => GameTag.fromJson(tag)).toList();
    cachedPacks = data["packs"]
        .map<JackboxPack>((pack) => JackboxPack.fromJson(pack))
        .toList();
    cachedCategories = data["patchsCategories"] != null
        ? data["patchsCategories"]
            .map<PatchCategory>((category) => PatchCategory.fromJson(category))
            .toList()
        : [];
    await applyExternalConfiguration();
  }

  Future<void> applyExternalConfiguration() async {
    List<Future> futures = [];
    for (JackboxPack pack in cachedPacks) {
      for (JackboxPackPatch patch in pack.patches) {
        if (patch.configuration != null) {
          if (patch.configuration!.versionOrigin ==
              OnlineVersionOrigin.REPO_FILE) {
            final rawData =
                getRequest(Uri.parse(patch.configuration!.versionFile));
            rawData.then((retrievedData) {
              final Map<String, dynamic> data = jsonDecode(retrievedData);
              patch.latestVersion = data[patch.configuration!.versionProperty]
                  .replaceAll("Build:", "")
                  .trim();
            });
            futures.add(rawData);
          }
        }
      }
      for (JackboxPackPatch patch in pack.fixes) {
        if (patch.configuration != null) {
          if (patch.configuration!.versionOrigin ==
              OnlineVersionOrigin.REPO_FILE) {
            final rawData =
                getRequest(Uri.parse(patch.configuration!.versionFile));
            rawData.then((retrievedData) {
              final Map<String, dynamic> data = jsonDecode(retrievedData);
              patch.latestVersion = data[patch.configuration!.versionProperty]
                  .replaceAll("Build:", "")
                  .trim();
            });
            futures.add(rawData);
          }
        }
      }
    }
    await Future.wait(futures);
  }

  Future<void> recoverNewsAndLinks() async {
    final rawData = await getRequest(
        Uri.parse('$baseEndpoint${APIEndpoints.WELCOME.path}'));
    final Map<dynamic, dynamic> welcome = jsonDecode(rawData);
    cachedNews =
        welcome["news"].map<News>((news) => News.fromJson(news)).toList();
  }

  Future<void> recoverBlurHashes() async {
    final rawData = await getRequest(
        Uri.parse('$baseEndpoint${APIEndpoints.BLUR_HASHES.path}'));
    final List<dynamic> data = jsonDecode(rawData);
    cachedBlurHashes =
        data.map<UrlBlurHash>((tag) => UrlBlurHash.fromJson(tag)).toList();
  }

  Future<void> recoverConfigurations() async {
    try {
      final rawData = await getRequest(
          Uri.parse('$baseEndpoint${APIEndpoints.CONFIGURATIONS.path}'));
      try {
        final Map<String, dynamic> data = jsonDecode(rawData);
        cachedConfigurations = PatchServerConfigurations.fromJson(data);
      } catch (e) {
        cachedConfigurations = PatchServerConfigurations.fromJson({});
      }
    } catch (e) {
      cachedConfigurations = PatchServerConfigurations.fromJson({});
    }
  }

  // Get packs
  List<JackboxPack> getPacks() {
    return cachedPacks;
  }

  // Get tags
  List<GameTag> getTags() {
    return cachedTags;
  }

  // Send get request
  Future<String> getRequest(Uri uri) async {
    JULogger().i("Sending GET request to $uri");
    http.Response response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      JULogger().e("Failed to send GET request to $uri");
      throw Exception("Failed to send GET request to $uri");
    }
  }

  // Download game patch
  Future<String> downloadPatch(
      String patchUri, void Function(double, double) progressCallback) async {
    Dio dio = Dio();
    final response = await dio.downloadUri(
        Uri.parse(APIService().assetLink(patchUri)),
        "./downloads/tmp.${patchUri.split(".").last}",
        options: Options(), onReceiveProgress: (received, total) {
      progressCallback(received.toInt().toDouble(), total.toInt().toDouble());
    });
    if (response.statusCode == 200) {
      return "./downloads/tmp.${patchUri.split(".").last}";
    } else {
      throw Exception('Failed to download patch');
    }
  }

  Future<String> downloadPackLoader(
      JackboxPack pack, void Function(double, double) progressCallback) async {
    Dio dio = Dio();
    final response = await dio.downloadUri(
        Uri.parse('$baseAssets/${pack.loader!.path}'),
        "./downloads/loader/${pack.id}/default.zip",
        onReceiveProgress: (received, total) {
      progressCallback(received.toDouble(), total.toDouble());
    });
    if (response.statusCode == 200) {
      return "./downloads/loader/${pack.id}/default.zip";
    } else {
      throw Exception('Failed to download patch');
    }
  }

  Future<String> downloadGameLoader(JackboxPack pack, JackboxGame game,
      void Function(double, double) progressCallback) async {
    Dio dio = Dio();
    final response = await dio.downloadUri(
        Uri.parse('$baseAssets/${game.loader!.path}'),
        "./downloads/loader/${pack.id}/${game.id}.zip",
        onReceiveProgress: (received, total) {
      progressCallback(received.toDouble(), total.toDouble());
    });
    if (response.statusCode == 200) {
      return "./downloads/loader/${pack.id}/${game.id}.zip";
    } else {
      throw Exception('Failed to download patch');
    }
  }

  String assetLink(String asset) {
    return asset.startsWith("http") ? asset : '$baseAssets/$asset';
  }

  String getDefaultBackground() {
    return '$baseAssets/backgrounds/default_background.png';
  }

  UrlBlurHash? getBlurHash(String url) {
    final blurHashes = cachedBlurHashes.where(
        (element) => element.url == url || element.url == assetLink(url));
    if (blurHashes.isNotEmpty) {
      return blurHashes.first;
    } else {
      return null;
    }
  }
}
