import 'package:fluent_ui/fluent_ui.dart';
import 'package:jackbox_patcher/model/usermodel/userjackboxpackpatch.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../../services/translations/translationsHelper.dart';

class DownloadPatchDialogComponent extends StatefulWidget {
  const DownloadPatchDialogComponent(
      {Key? key, required this.localPaths, required this.patchs})
      : super(key: key);

  final List<String> localPaths;
  final List<dynamic> patchs;

  @override
  State<DownloadPatchDialogComponent> createState() =>
      _DownloadPatchDialogComponentState();
}

class _DownloadPatchDialogComponentState
    extends State<DownloadPatchDialogComponent> {
  String status = "";
  String substatus = "";
  double progression = 0;

  int downloadingProgress = 0;
  int currentPatchDownloading = 0;

  @override
  void initState() {
    _startDownload();
    super.initState();
  }

  void _startDownload() async {
    downloadingProgress = 1;
    setState(() {});
    for (var patch in widget.patchs) {
      await patch.downloadPatch(widget.localPaths[currentPatchDownloading],
          (stat, substat, progress) async {
        status = stat;
        substatus = substat;
        if (progression.toInt() != progress.toInt()) {
          WindowsTaskbar.setProgress(
              progress.toInt() + (currentPatchDownloading) * 100,
              100 * widget.patchs.length);
        }
        progression = progress;
        setState(() {});
      });
      currentPatchDownloading++;
    }
    downloadingProgress = 2;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return downloadingProgress == 0
        ? ContentDialog(
            title:
                Text(TranslationsHelper().appLocalizations!.installing_a_patch),
            content: Text(TranslationsHelper()
                .appLocalizations!
                .installing_a_patch_description),
            actions: [
              HyperlinkButton(
                onPressed: () => Navigator.pop(context),
                child: Text(TranslationsHelper().appLocalizations!.cancel),
              ),
              HyperlinkButton(
                onPressed: () async {},
                child:
                    Text(TranslationsHelper().appLocalizations!.page_continue),
              ),
            ],
          )
        : (downloadingProgress == 1
            ? buildDownloadingPatchDialog(status, substatus, progression)
            : buildFinishDialog());
  }

  ContentDialog buildDownloadingPatchDialog(
      String status, String substatus, double progression) {
    return ContentDialog(
      title: Text(TranslationsHelper().appLocalizations!.installing_a_patch),
      content: SizedBox(
          height: 200,
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                ProgressRing(value: progression),
                const SizedBox(height: 10),
                Text(
                    "[${currentPatchDownloading + 1}/${widget.patchs.length}] " +
                        (widget.patchs[currentPatchDownloading]
                                is UserJackboxPackPatch
                            ? widget.patchs[currentPatchDownloading]
                                .getPack()
                                .pack
                                .name
                            : widget.patchs[currentPatchDownloading]
                                .getGame()
                                .game
                                .name),
                    style: const TextStyle(fontSize: 20)),
                Text(status, style: const TextStyle(fontSize: 20)),
                Text(substatus, style: const TextStyle(fontSize: 16)),
              ]))),
      actions: progression == 0
          ? [
              HyperlinkButton(
                onPressed: () {
                  WindowsTaskbar.setProgressMode(
                      TaskbarProgressMode.noProgress);
                  Navigator.pop(context);
                  downloadingProgress = 0;
                  setState(() {});
                },
                child: Text(TranslationsHelper().appLocalizations!.cancel),
              ),
            ]
          : [],
    );
  }

  ContentDialog buildFinishDialog() {
    return ContentDialog(
      actions: [
        HyperlinkButton(
          onPressed: () {
            WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
            Navigator.pop(context);
            downloadingProgress = 0;
            setState(() {});
          },
          child: Text(TranslationsHelper().appLocalizations!.close),
        ),
      ],
      title: Text(TranslationsHelper().appLocalizations!.installing_a_patch),
      content: SizedBox(
          height: 200,
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                const Icon(FluentIcons.check_mark),
                const SizedBox(height: 10),
                Text(
                    TranslationsHelper()
                        .appLocalizations!
                        .installing_a_patch_end,
                    style: const TextStyle(fontSize: 20)),
                Text(TranslationsHelper().appLocalizations!.can_close_popup,
                    style: const TextStyle(fontSize: 16)),
              ]))),
    );
  }
}
