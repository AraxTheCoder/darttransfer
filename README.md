# Darttransfer
A simple Dart Wetransfer Client

## Support
At the moment this client **only supports uploading files** to Wetransfer and receiving a short url download link

## Installing
Download the project and save it on the disk.
<br><br>
Then add it to your pubspec.yaml like this:
```yaml
dependencies:
  darttransfer:
    path: ../path/to/package/darttransfer/
```

## Usage
```dart
import 'package:darttransfer/darttransfer.dart';

void main(List<String> arguments) async {
  DarttransferUploader wetransferUploader = DarttransferUploader();

  await wetransferUploader.upload([
    "filepath/to/file/test.txt",
    "filepath/to/file/test.zip"
  ], displayName: "DisplayName", message: "Message");
}
```