import 'package:fluent_ui/fluent_ui.dart';

import '../../services/translations/translationsHelper.dart';

class ConfirmationDialog extends StatefulWidget {
  ConfirmationDialog(
      {Key? key, required this.toConfirm, required this.todoWhenConfirmed})
      : super(key: key);

  final String toConfirm;
  final Function todoWhenConfirmed;

  @override
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(TranslationsHelper().appLocalizations!.confirmation),
      content: Text(
          TranslationsHelper().appLocalizations!.confirmation_description(widget.toConfirm)),
      actions: [
        HyperlinkButton(
          onPressed: () => Navigator.pop(context),
          child: Text(TranslationsHelper().appLocalizations!.cancel),
        ),
        HyperlinkButton(
          onPressed: () async {
            await widget.todoWhenConfirmed();
            Navigator.pop(context);
          },
          child: Text(TranslationsHelper().appLocalizations!.confirm),
        ),
      ],
    );
  }
}
