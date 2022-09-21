import 'package:darttransfer/darttransfer.dart';


void main(List<String> arguments) async {
  DarttransferUploader wetransferUploader = DarttransferUploader();

  await wetransferUploader.upload(arguments, displayName: "DisplayName", message: "Message");
}
