import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart';
import 'package:darttransfer/src/networking/session.dart';

class DarttransferUploader {
  static const int WETRANSFER_DEFAULT_CHUNK_SIZE = 5242880;
  static const int WETRANSFER_EXPIRE_IN = 604800;

  /// Uploads Files by filepath [files] to Wetransfer 
  /// 
  /// Optional: 
  /// Display name [displayName]
  /// Message [message]
  /// 
  /// Returns short Url Wetransfer download link
  Future<String> upload(List<String> files, {String displayName = "Default Display Name", String message = ""}) async{
    // Check that all files exists
    for(String file in files){
      if(!File(file).existsSync()){
        throw Exception("File {$file} not found!");
      }
    }

    // Check that there are no duplicates filenames
    // (despite possible different dirname())
    Set<String> filenames = files.map((file) => File(file).uri.pathSegments.last).toSet();

    if(filenames.length != files.length){
      throw Exception("Duplicate filenames!");
    }

    Session session = await prepareSession();

    String transferId = await prepareLinkUpload(files, displayName, message, session);

    for(String file in files){
      String fileId = await prepareFileUpload(transferId, file, session);
      await uploadChunks(transferId, fileId, file, session);
    }

    String shortUrl = await finalizeUpload(transferId, session);

    close(session);

    return shortUrl;
  }

  /// Prepares the Session with the required cookies
  /// 
  /// Returns [Session]
  Future<Session> prepareSession() async {
    Session session = Session(
      defaultHeaders: {
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'accept-language': 'de-DE,de;q=0.9',
        'sec-ch-ua': '"Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'none',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
        'Accept-Encoding': 'gzip',
      }
    );

    var res = await session.get('https://wetransfer.com/', extraHeaders: {
      'authority': 'wetransfer.com',
    });
    if (res.statusCode != 200) throw Exception('http.get error: statusCode= ${res.statusCode}');
    String setCookie = res.headers['set-cookie']!;

    String? snowplowId0497 = setCookie.substring(0, setCookie.indexOf(";") + 1);

    session.addCookie("_wt_snowplowses.0497=*;");
    session.addCookie(snowplowId0497);

    return session;
  }

  /// Returns a [Map] with the filename and size
  Map<String, dynamic> fileNameAndSize(String filepath) {
    File file = File(filepath);

    String filename = file.uri.pathSegments.last;
    int filesize = file.lengthSync();

    return {"item_type": "file", "name": filename, "size": filesize};
  }

  /// Sends a prepare request containing the filesizes and names to wetransfer
  /// 
  /// Returns [transferId]
  Future<String> prepareLinkUpload(List<String> filenames, String displayName, String message, Session session) async {
    
    List<Map<String, dynamic>> files = [];

    for(String file in filenames){
      files.add(fileNameAndSize(file));
    }

    Map data = {
      '"message"': '"${message}"',
      '"display_name"': '"${displayName}"',
      '"ui_language"': '"de"',
      '"files"': jsonEncode(files),
    };

    Response res = await session.post('https://wetransfer.com/api/v4/transfers/link', data.toString(), extraHeaders: {
      'authority': 'wetransfer.com',
      'accept': 'application/json, text/plain, */*',
      'origin': 'https://wetransfer.com',
      'referer': 'https://wetransfer.com/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'content-type': 'application/json',
    });
    if (res.statusCode != 200) throw Exception('http.post error: statusCode= ${res.statusCode} response:${res.body}');

    return jsonDecode(res.body)['id'];
  }

  /// Sends a prepare request containing the specific filesize and name to wetransfer
  /// 
  /// Returns [fileId]
  Future<String> prepareFileUpload(String transferId, String file, Session session) async {
    Map<String, dynamic> data = fileNameAndSize(file);

    var headers = {
      'authority': 'wetransfer.com',
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'de-DE,de;q=0.9',
      'content-type': 'application/json',
      'origin': 'https://wetransfer.com',
      'referer': 'https://wetransfer.com/',
      'sec-ch-ua': '"Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
      'Accept-Encoding': 'gzip',
    };

    Response res = await session.post('https://wetransfer.com/api/v4/transfers/$transferId/files', jsonEncode(data), extraHeaders: headers);

    if (res.statusCode != 200) throw Exception('http.post error: statusCode= ${res.statusCode}');

    return jsonDecode(res.body)['id']; 
  }

  /// Uploads the [file] in chunks to wetransfer with the coresponding [transferId] ans [fileId]
  Future<void> uploadChunks(String transferId, String fileId, String file, Session session, {int defaultChunkSize = WETRANSFER_DEFAULT_CHUNK_SIZE}) async {
    RandomAccessFile raf = File(file).openSync(mode: FileMode.read);

    int chunkNumber = 0;

    while(true){
      raf.setPositionSync(chunkNumber * defaultChunkSize);
      Uint8List chunk = raf.readSync(defaultChunkSize);
      int chunkSize = chunk.length;
      if(chunkSize == 0){
        break;
      }
      chunkNumber++;

      Map<String, dynamic> data = {
        "chunk_crc": getCrc32(chunk),
        "chunk_number": chunkNumber,
        "chunk_size": chunkSize,
        "retries": 0
      };

      Response res = await session.post('https://wetransfer.com/api/v4/transfers/$transferId/files/$fileId/part-put-url', jsonEncode(data), extraHeaders: {
        'authority': 'wetransfer.com',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'de-DE,de;q=0.9',
        'content-type': 'application/json',
        'origin': 'https://wetransfer.com',
        'referer': 'https://wetransfer.com/',
        'sec-ch-ua': '"Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
        'Accept-Encoding': 'gzip',
      });

      String url = jsonDecode(res.body)['url'];

      // await session.options(url, {
      //   'Origin': 'https://wetransfer.com',
      //   'Access-Control-Request-Method': 'PUT',
      // });

      await session.put(url, chunk, extraHeaders: {
        'content-length': '$chunkSize',
        'content-type': 'binary/octet-stream'
      });
    }

    raf.closeSync();

    String data = '{"chunk_count":$chunkNumber}';

    await session.put('https://wetransfer.com/api/v4/transfers/$transferId/files/$fileId/finalize-mpp', data, extraHeaders: {
      'authority': 'wetransfer.com',
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'de-DE,de;q=0.9',
      'content-type': 'application/json',
      'content-length': '${utf8.encode(data).length}',
      'origin': 'https://wetransfer.com',
      'referer': 'https://wetransfer.com/',
      'sec-ch-ua': '"Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
      'Accept-Encoding': 'gzip',
    });
  }

  /// Sends a finalize request to wetransfer to end all transmissions
  /// 
  /// Returns [shortendUrl] of the download link
  Future<String> finalizeUpload(String transferId, Session session) async {
    Response res = await session.put('https://wetransfer.com/api/v4/transfers/$transferId/finalize', null, extraHeaders: {
      'authority': 'wetransfer.com',
      'accept': 'application/json, text/plain, */*',
      'accept-language': 'de-DE,de;q=0.9',
      'content-length': '0',
      'content-type': 'application/x-www-form-urlencoded',
      'origin': 'https://wetransfer.com',
      'referer': 'https://wetransfer.com/',
      'sec-ch-ua': '"Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36',
      'Accept-Encoding': 'gzip',
    });

    return jsonDecode(res.body)['shortened_url'];
  }

  /// Closes the provided [Session]
  void close(Session s) {
    s.close();
  }
}
