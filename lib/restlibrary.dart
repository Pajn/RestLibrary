library RestLibrary;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';
import 'package:quiver/pattern.dart';

typedef void Preprocessor(HttpRequest request);
typedef Future<Response> Processor(Request request);

/// A simple REST server for quickly bringing up basic REST or REST inspired APIs.
class RestServer {
    List<Route> _routes = new List();
    List<Preprocessor> _temp_preprocessors = new List();
    VirtualDirectory _staticServer;

    RestServer() {
    }

    /// Add a [preprocessor] that it will be called before the callback on subsequent routes.
    void preprocessor(Preprocessor preprocessor) => _temp_preprocessors.add(preprocessor);

    /// Remove a [preprocessor] so that it will no longer be called on subsequent routes.
    bool removePreprocessor(Preprocessor preprocessor) => _temp_preprocessors.remove(preprocessor);

    /// Remove all preprocessors so that they will no longer be called on subsequent routes.
    void clearAllPreprocessors() => _temp_preprocessors.clear();

    /// Add a route. If any preprocessors have been added before, they will be called on this route.
    void route(Route route) {
        //var route = new Route(path, _temp_authorizations.toList());
        route.preprocessors = _temp_preprocessors.toList();
        _routes.add(route);
    }

    /// Supply a directory to serve static files from
    void static(String path) {
        _staticServer = new VirtualDirectory(path)
            ..allowDirectoryListing = true
            ..followLinks = true
            ..errorPageHandler = _send404;

        _staticServer.directoryHandler = (Directory dir, HttpRequest req) {
            var filePath = '${dir.path}${Platform.pathSeparator}index.html';
            var file = new File(filePath);
            _staticServer.serveFile(file, req);
        };
    }

    /// Bind the server to a socket and start handling requests.
    void start({InternetAddress address: null, int port: 80}) {
        address = address != null ? address : InternetAddress.LOOPBACK_IP_V4;

        HttpServer.bind(address, port).then((server) {
            server.listen(handle);
        });
    }

    /// Is called internally, there are usually no reason to call this manually.
    ///
    /// Will call the matching route if it exists, else it will return a 404 Not Found Error.
    /// If any uncaught exception is caught it will return a 500 Internal server Error.
    void handle(HttpRequest request) {
        try {
            request.response.headers..set('Access-Control-Allow-Origin', '*')
                                    ..contentType = new ContentType('application', 'json', charset: 'utf-8');

            var route = _routes.where((route) => route.match(request.uri.path));

            if (route.isNotEmpty) {
                request.response.statusCode = HttpStatus.OK;
                route.first.handle(request).then((response) => request.response.write(response),
                        onError: (e) {
                            request.response..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
                                            ..write(new Response(e.toString(), status: Status.ERROR));
                        }).whenComplete(request.response.close);
            } else if (_staticServer != null) {
                _staticServer.serveRequest(request);
            } else {
                _send404(request);
            }
        } catch (e) {
            request.response..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
                            ..write(new Response(e.toString(), status: Status.ERROR))
                            ..close();
        }
    }

    void _send404(HttpRequest request) {
        request.response..headers.set('Access-Control-Allow-Origin', '*')
                        ..headers.contentType = new ContentType('application', 'json', charset: 'utf-8')

                        ..statusCode = HttpStatus.NOT_FOUND
                        ..write(new Response("not found", status: Status.ERROR))
                        ..close();
    }
}

/// Handles a specific route.
class Route {
    static final RegExp _urlParameter = new RegExp(r'\\{(\w+)(?::([is]))?\\}');

    RegExp _urlPattern;
    List<String> _parameters = [];
    List<Preprocessor> preprocessors = new List();
    Processor get;
    Processor post;
    Processor put;
    Processor delete;

    Route(String url) {
        url = escapeRegex(url);

        _urlParameter.allMatches(url).forEach((match) {
            var parameter = match.group(1);
            _parameters.add(parameter);

            var to;
            switch(match.group(2)) {
                case 'i':
                    to = r'(\d+)';
                    break;
                case 's':
                default:
                    to = r'(\w+)';
            }

            url = url.replaceFirst(_urlParameter, to);
        });

        _urlPattern = new RegExp('^$url/?\$');
    }

    /// Checks if the [uri] matches this [Route]
    bool match(String path) => _urlPattern.hasMatch(path);

    /// Extracts the parameters from the [path] and puts them in a map with the name as the key.
    Map<String, String> extractParameters(String path) {
        Map<String, String> parameters = {};
        var match = _urlPattern.firstMatch(path);

        for (int i = 0; i < _parameters.length; i++) {
            parameters[_parameters[i]] = match.group(i+1);
        }

        return parameters;
    }

    /// Is called internally, there are usually no reason to call this manually.
    ///
    /// Will first run all [preprocessors] associated with this route.
    /// Will then call the correct callback if set, else it will return a Method Not Allowed error.
    Future<Response> handle(HttpRequest httpRequest) {
        try {
            preprocessors.forEach((preprocessor) => preprocessor(httpRequest));
        } on AuthorizationException catch (e) {
            httpRequest.response.statusCode = HttpStatus.UNAUTHORIZED;
            return new Future.sync(() => new Response(e.toString(), status: Status.FAIL));
        }

        var request = new Request(httpRequest, extractParameters(httpRequest.uri.path));

        if (httpRequest.method == 'GET' && get != null) {
            return get(request);
        } else if (httpRequest.method == 'POST' && post != null) {
            return post(request);
        } else if (httpRequest.method == 'PUT' && put != null) {
            return put(request);
        } else if (httpRequest.method == 'DELETE' && delete != null) {
            return delete(request);
        } else {
            httpRequest.response.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
            return new Future.sync(() => new Response("Method not allowed", status: Status.ERROR));
        }
    }
}

class Request {
    final HttpRequest httpRequest;
    final Map<String, String> urlParameters;

    Request(HttpRequest this.httpRequest, Map<String, String> this.urlParameters);
}

/// A [JSend][] response body.
///
/// [JSEND]: http://labs.omniti.com/labs/jsend
class Response {
    final Status status;
    final Object data;

    Response(Object this.data, {Status this.status: Status.SUCCESS});

    /// Returns a JSON representation of the response.
    String toString() {
        if (status == Status.ERROR) {
            return JSON.encode({
                "status" : status.value,
                "message" : data
            });
        } else {
            return JSON.encode({
                "data" : data,
                "status" : status.value
            });
        }
    }
}

/// An enum containing [JSend][] accepted status codes.
///
/// [JSEND]: http://labs.omniti.com/labs/jsend
class Status {
  static const SUCCESS = const Status._("success");
  static const FAIL = const Status._("fail");
  static const ERROR = const Status._("error");

  final String value;

  const Status._(this.value);
}

/// An exception raised when authorization fails.
class AuthorizationException implements Exception {
    /// A static, machine readable, error code.
    final String error;

    /// A human readable description of the error.
    final String description;

    /// Creates an AuthorizationException.
    AuthorizationException(this.error, this.description);

    /// Provides a string description of the AuthorizationException.
    String toString() {
        var message = 'Authorization error ($error)';
        if (description != null) {
            message = '$message: $description';
        }
        return message;
    }
}
