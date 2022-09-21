import 'package:darttransfer/darttransfer.dart';

void main(List<String> arguments) async {
  DarttransferUploader wetransferUploader = DarttransferUploader();

  String downloadUrl = await wetransferUploader.upload([
    r"../test/res/simpleText.txt"
  ], displayName: "DisplayName", message: "Message");

  print(downloadUrl);
}
