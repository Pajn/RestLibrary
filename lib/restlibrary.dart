library RestLibrary;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http_server/http_server.dart';
import "package:path/path.dart";
import 'package:quiver/pattern.dart';

typedef Preprocessor(HttpRequest request);
typedef Response Processor(Request request);

/// A simple REST server for quickly bringing up basic REST or REST inspired APIs.
class RestServer {
    List<String> clientRoutes = [];
    List<Route> _routes = [];
    List<Preprocessor> _temp_preprocessors = [];
    bool _staticJailRoot;
    String _staticPath;
    VirtualDirectory _staticServer;

    /// Add a [preprocessor] that it will be called before the callback on subsequent routes.
    void preprocessor(Preprocessor preprocessor) => _temp_preprocessors.add(preprocessor);

    /// Remove a [preprocessor] so that it will no longer be called on subsequent routes.
    bool removePreprocessor(Preprocessor preprocessor) => _temp_preprocessors.remove(preprocessor);

    /// Remove all preprocessors so that they will no longer be called on subsequent routes.
    void clearAllPreprocessors() => _temp_preprocessors.clear();

    /// Add a route. If any preprocessors have been added before, they will be called on this route.
    void route(Route route) {
        route.preprocessors = _temp_preprocessors.toList();
        _routes.add(route);
    }

    /// Supply a directory to serve static files from
    void static(String path, {bool jailRoot: true}) {
        _staticPath = path;
        _staticJailRoot = jailRoot;

        _staticServer = new VirtualDirectory(path)
            ..allowDirectoryListing = true
            ..followLinks = true
            ..jailRoot = jailRoot
            ..errorPageHandler = _send404;

        _staticServer.directoryHandler = (Directory dir, HttpRequest req) {
            var filePath = '${dir.path}${Platform.pathSeparator}index.html';
            var file = new File(filePath);
            _staticServer.serveFile(file, req);
        };

        _staticServer.errorPageHandler = _checkClientRoute;
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
            var route = _routes.where((route) => route.match(request.uri.path));

            if (route.isNotEmpty) {
                _setHeaders(request);

                route.first.handle(request).then((response) {
                    if (request.response.statusCode == null) {
                        if (response != null && response.status == Status.SUCCESS) {
                            request.response.statusCode = HttpStatus.OK;
                        } else {
                            _send500(request, new ArgumentError('No response returned'));
                        }
                    }
                    request.response..write(response)
                                    ..close();
                }, onError: (e) {
                    _send500(request, e);
                });
            } else if (_staticServer != null) {
                _staticServer.serveRequest(request);
            } else {
                _send404(request);
            }
        } catch (e) {
            _send500(request, e);
        }
    }

    void _checkClientRoute(HttpRequest request) {
        var path = request.uri.path;

        // Don't allow navigating up paths.
        if (path.split('/').contains('..')) {
            return _send404(request);
        }

        var route = clientRoutes.firstWhere((alias) => path.startsWith(alias), orElse: () => null);
        if (route == null) {
            return _send404(request);
        }
        path = path.substring(route.length);
        if (path.startsWith('/')) {
            path = path.substring(1);
        }

        _handleResource(path, request);
    }

    void _handleResource(String path, HttpRequest request) {
        path = normalize(path);

        // If we jail to root, the relative path can never go up.
        if (_staticJailRoot && split(path).first == "..") {
            return _send404(request);
        };

        String fullPath = join(_staticPath, path);
        FileSystemEntity.type(fullPath, followLinks: false).then((type) {
            switch (type) {
                case FileSystemEntityType.FILE:
                    request.response.statusCode = HttpStatus.OK;
                    return _staticServer.serveFile(new File(fullPath), request);

                case FileSystemEntityType.DIRECTORY:
                    request.response.statusCode = HttpStatus.OK;
                    fullPath = '$fullPath${Platform.pathSeparator}index.html';
                    return _staticServer.serveFile(new File(fullPath), request);

                case FileSystemEntityType.LINK:
                    return new Link(fullPath).target().then((target) {
                        String targetPath = normalize(target);
                        if (isAbsolute(targetPath)) {
                            // If we jail to root, the path can never be absolute.
                            if (_staticJailRoot) return null;
                            return _handleResource(targetPath, request);
                        } else {
                            targetPath = join(dirname(path), targetPath);
                            return _handleResource(targetPath, request);
                        }
                    });

                default:
                    return _send404(request);
            }
        });
    }

    void _send404(HttpRequest request) {
        _setHeaders(request);

        request.response..statusCode = HttpStatus.NOT_FOUND
            ..write(new Response("not found", status: Status.ERROR))
            ..close();
    }

    void _send500(HttpRequest request, e) {
        _setHeaders(request);

        request.response..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
                        ..write(new Response(e.toString(), status: Status.ERROR))
                        ..close();
    }

    void _setHeaders(HttpRequest request) {
        request.response..headers.set('Access-Control-Allow-Origin', '*')
                        ..headers.contentType = new ContentType('application', 'json', charset: 'utf-8');
    }
}

/// Handles a specific route.
class Route {
    static final RegExp _urlParameter = new RegExp(r'\\{(\w+)(?::([is]))?\\}');

    RegExp _urlPattern;
    bool _parseJson;
    List<String> _parameters = [];
    List<Preprocessor> preprocessors = new List();
    Processor get;
    Processor post;
    Processor put;
    Processor delete;

    Route(String url, {bool parseJson: true}) {
        url = escapeRegex(url);
        _parseJson = parseJson;

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
        var runningPreprocessors = preprocessors.map((preprocessor) =>
                                                        new Future(() => preprocessor(httpRequest))
                                                    );
        
        return Future.wait(runningPreprocessors).then((_) {
            
            var request = new Request(httpRequest, extractParameters(httpRequest.uri.path));
    
            if (httpRequest.method == 'GET' && get != null) {
                return _call(get, request);
            } else if (httpRequest.method == 'POST' && post != null) {
                var list;
                if (_parseJson && (list = httpRequest.toList()) != null) {
                    return _callWithJson(post, request, list);
                } else {
                    return _call(post, request);
                }
            } else if (httpRequest.method == 'PUT' && put != null) {
                var list;
                if (_parseJson && (list = httpRequest.toList()) != null) {
                    return _callWithJson(put, request, list);
                } else {
                    return _call(put, request);
                }
            } else if (httpRequest.method == 'DELETE' && delete != null) {
                return _call(delete, request);
            } else if (httpRequest.method == 'OPTIONS') {
                return _respondToCorsRequest(httpRequest);
            } else {
                httpRequest.response.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
                return new Response("Method not allowed", status: Status.ERROR);
            }
        }).catchError((e) {
            if (e is AuthorizationException) {
                httpRequest.response.statusCode = HttpStatus.UNAUTHORIZED;
                return new Response(e.toString(), status: Status.FAIL);
            } else {
                throw e;
            }
        });
    }
    
    Response _respondToCorsRequest(HttpRequest httpRequest) {
        var allowedMethods = [];
        allowedMethods.add((get != null) ? 'GET' : null);
        allowedMethods.add((post != null) ? 'POST' : null);
        allowedMethods.add((put != null) ? 'PUT' : null);
        allowedMethods.add((delete != null) ? 'DELETE' : null);
        allowedMethods = allowedMethods.where((method) => method != null);

        var response = httpRequest.response;

        response.headers.add('Access-Control-Allow-Methods', allowedMethods.join(', '));
        response.headers.add('Access-Control-Allow-Headers',
                httpRequest.headers['Access-Control-Request-Headers']);

        return new Response('');
    }

    Future<Response> _call(Processor processor, Request request) => new Future(() => processor(request));

    dynamic _callWithJson(Processor processor, Request request, Future<List<List<int>>> list) {
        return list.then((List<List<int>> buffer) {
            var json = new String.fromCharCodes(buffer.expand((i) => i).toList());
            request.json = JSON.decode(json);

            return _call(processor, request).catchError((_) {
                request.httpRequest.response.statusCode = HttpStatus.BAD_REQUEST;
                return new Response('Malformed JSON', status: Status.ERROR);
            }, test: (e) => e is ArgumentError);
        }).catchError((_) {
            request.httpRequest.response.statusCode = HttpStatus.BAD_REQUEST;
            return new Response('JSON Syntax Error', status: Status.ERROR);
        }, test: (e) => e is FormatException);
    }
}

class Request {
    final HttpRequest httpRequest;
    final Map<String, String> urlParameters;

    var json;

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
