import 'package:http/http.dart' as http;

class Session {
  final Map<String, String> defaultHeaders;
  final http.Client client = http.Client();

  Session({
    this.defaultHeaders = const{}
  });

  Future<http.Response> get(String url, {Map<String, String>? extraHeaders}) async {
    Map<String, String> requestHeaders = Map.from(defaultHeaders);
    if(extraHeaders != null){
      requestHeaders.addEntries(extraHeaders.entries);
    }

    http.Response response = await client.get(Uri.parse(url), headers: requestHeaders);

    return response;
  }

  Future<http.Response> post(String url, dynamic data, {Map<String, String>? extraHeaders}) async {
    Map<String, String> requestHeaders = Map.from(defaultHeaders);
    if(extraHeaders != null){
      requestHeaders.addEntries(extraHeaders.entries);
    }

    http.Response response = await client.post(Uri.parse(url), body: data, headers: requestHeaders);
    
    return response;
  }

  Future<http.Response> put(String url, dynamic data, {Map<String, String>? extraHeaders}) async {
    Map<String, String> requestHeaders = Map.from(defaultHeaders);
    if(extraHeaders != null){
      requestHeaders.addEntries(extraHeaders.entries);
    }

    http.Response response = await client.put(Uri.parse(url), body: data, headers: requestHeaders);
    
    return response;
  }

  /// Sends an [OPTIONS] Request with [extraHeaders] as body data
  /// 
  /// Returns [http.Response]
  Future<http.Response> options(String url, {Map<String, String>? extraHeaders}) async {
    Map<String, String> requestHeaders = Map.from(defaultHeaders);
    if(extraHeaders != null){
      requestHeaders.addEntries(extraHeaders.entries);
    }

    http.Response response = await http.Response.fromStream(await client.send(http.Request('OPTIONS', Uri.parse(url))..bodyFields = requestHeaders));
    
    return response;
  }

  /// Adds a single Cookie [String] to the 'cookie' Header
  /// 
  /// Format:
  /// ```cookieName=cookieValue;```
  void addCookie(String cookie){
    if(defaultHeaders['cookie'] != null){
      defaultHeaders['cookie'] = defaultHeaders['cookie']! + cookie;
    }else{
      defaultHeaders['cookie'] = cookie;
    }
  }

  /// Closes the [http.Client]
  void close() {
    client.close();
  }
}
