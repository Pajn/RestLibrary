import 'package:RestLibrary/restlibrary.dart';

void main() {
    var restServer = new RestServer()
        ..route(new Route('/hello')
                ..get = helloGet
                ..post = helloPost)
        ..route(new Route('/hello/{name}')
                ..get = helloGetUrl)
        ..route(new Route('/json')
                ..post = helloJson
                ..put = helloJson)
        ..preprocessor(checkPassword)
        ..route(new Route('/private')
                ..get = helloGet);
    
    new HttpTransport(restServer, port: 8080)
        ..static('web', clientRoutes: ['/client']);
}

/// A callback function that will return "Hello, World!", or if the name query parameter is provided
/// "Hello, {name}!".
Response helloGet(Request request) {
    var name = request.queryParameters['name'];
    name = name != null ? name : 'World';
    return new Response("Hello, $name!");
}

/// A callback function that will return "Hello, World!", or if post data is provided
/// "Hello, {postData}!".
helloPost(Request request) {
    var name = request.body != null ? request.body : 'World';
    return new Response("Hello, $name!");
}

/// A callback function that will return "Hello, {name}! where name is extracted from the url name
/// parameter.
Response helloGetUrl(Request request) {
    var name = request.urlParameters['name'];
    return new Response("Hello, $name!");
}

/// A callback function that will return "Hello, World!", or if json is provided
/// as post data, "Hello, {name}!" where name is specified in json like {"name":"Foo"}.
Response helloJson(Request request) {
    var name = request.body['name'];
    if (name == null) { name = 'World'; }

    return new Response("Hello, $name!");
}

/// A preprocessor that throws [AuthorizationException] if the password is not correct
checkPassword(Request request) {
    if (request.queryParameters['password'] != 'secret') {
        throw new AuthorizationException('Wrong password', 'The password is secret');
    }
}
