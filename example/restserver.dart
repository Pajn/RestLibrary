import 'dart:async';
import 'package:RestLibrary/restlibrary.dart';

void main() {
    new RestServer()
        ..static('web')
        ..route(new Route('/hello', parseJson: false)
                ..get = helloGet
                ..post = helloPost)
        ..route(new Route('/hello/{name}')
                ..get = helloGetUrl)
        ..route(new Route('/hellosession', parseJson: false)
                ..get = helloGetSession
                ..post = helloPostSession)
        ..route(new Route('/json')
                ..post = helloJson
                ..put = helloJson)
        ..start(port: 8080);
}

/// A callback function that will return "Hello, World!", or if the name query parameter is provided
/// "Hello, {name}!".
Response helloGet(Request request) {
    var name = request.httpRequest.uri.queryParameters['name'];
    name = name != null ? name : 'World';
    return new Response("Hello, $name!");
}

/// A callback function that will return "Hello, World!", or if post data is provided
/// "Hello, {postData}!".
helloPost(Request request) {
    return request.httpRequest.toList().then((List<List<int>> buffer) {
        var name = new String.fromCharCodes(buffer.expand((i) => i).toList());
        name = name.isNotEmpty ? name : 'World';
        return new Response("Hello, $name!");
    });
}

/// A callback function that will return "Hello, {name}! where name is extracted from the url name
/// parameter.
Response helloGetUrl(Request request) {
    var name = request.urlParameters['name'];
    return new Response("Hello, $name!");
}

/// A callback function that will return "Hello, World!", or if the name session variable exists
/// "Hello, {name}!".
Response helloGetSession(Request request) {
    var name = request.httpRequest.session['name'];
    name = name != null ? name : 'World';
    return new Response("Hello, $name!");
}

/// A callback function that will set the name session variable to the post data
helloPostSession(Request request) {
    return request.httpRequest.toList().then((List<List<int>> buffer) {
        var name = new String.fromCharCodes(buffer.expand((i) => i).toList());
        request.httpRequest.session['name'] = name;
        return new Response("The name session variable is set to '$name'");
    });
}

/// A callback function that will return "Hello, World!", or if json is provided
/// as post data, "Hello, {name}!" where name is specified in json like {"name":"Foo"}.
Response helloJson(Request request) {
    var name = request.json['name'];
    if (name == null) { name = 'World'; }

    return new Response("Hello, $name!");
}
