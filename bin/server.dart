import 'dart:io';

Future main() async {
  var server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    4040,
  );
  print('Listening on localhost:${server.port}');

  await for (HttpRequest request in server) {
    handleRequest(request);
    await request.response.close();
  }
}

void handleRequest(HttpRequest request){
  try{
    if(request.method == 'GET'){
      handleGet(request);
    } else {
      request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..write('Unsupported request: ${request.method}.')
          ..close();
    }
  } catch (e) {
    print('Exception in handleRequest: $e');
  }

  print('Request handled');
}

void handleGet(HttpRequest request) {
//  final guess = request.uri.queryParameters
  final response = request.response;
  response.statusCode = HttpStatus.ok;
  response
    ..statusCode = HttpStatus.ok
    ..writeln('true')
    ..close();
}

void handlePost(HttpRequest request){

}