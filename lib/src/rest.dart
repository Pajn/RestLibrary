part of RestLibrary;

typedef Preprocessor(Request request);
typedef Response Processor(Request request);

/// A simple REST server for quickly bringing up basic REST or REST inspired APIs.
class RestServer {
    List<Route> _routes = [];
    List<Preprocessor> _temp_preprocessors = [];

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
    
    /// Will call the matching route if it exists, else it will return a 404 Not Found Error.
    /// If any uncaught exception is caught it will return a 500 Internal server Error.
    Future<Response> handle(Request request) {
        try {
            var route = _routes.where((route) => route.match(request.path));

            if (route.isNotEmpty) {
                return route.first.handle(request).then((response) {
                    if (response == null) {
                        return _send500(request, new ArgumentError('No response returned'));
                    }
                    return response;
                }, onError: (e) => _send500(request, e));
            } else {
                return new Future.sync(() => _send404(request));
            }
        } catch (e) {
            return new Future.sync(() => _send500(request, e));
        }
    }

    Response _send404(Request request) =>
            new Response("Not found", status: Status.ERROR, statusCode: HttpStatus.NOT_FOUND);

    Response _send500(Request request, e) =>
            new Response(e.toString(), status: Status.ERROR, statusCode: HttpStatus.INTERNAL_SERVER_ERROR);
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

    /// Extracts the url parameters from the [path] and puts them in a map with the name as the key.
    Map<String, String> extractUrlParameters(String path) {
        Map<String, String> parameters = {};
        var match = _urlPattern.firstMatch(path);

        for (int i = 0; i < _parameters.length; i++) {
            parameters[_parameters[i]] = match.group(i+1);
        }

        return parameters;
    }

    /// Extracts the query parameters from the [path] and puts them in a map with the name as the key.
    Map<String, String> extractQueryParameters(String path) =>
        Uri.parse(path).queryParameters;

    /// Is called internally, there are usually no reason to call this manually.
    ///
    /// Will first run all [preprocessors] associated with this route.
    /// Will then call the correct callback if set, else it will return a Method Not Allowed error.
    Future<Response> handle(Request request) {
        request.urlParameters = extractUrlParameters(request.path);
        
        var runningPreprocessors = preprocessors.map((preprocessor) =>
                                                        new Future(() => preprocessor(request))
                                                    );
        
        return Future.wait(runningPreprocessors).then((_) {    
            if (request.method == 'GET' && get != null) {
                return _call(get, request);
            } else if (request.method == 'POST' && post != null) {
                return _call(post, request);
            } else if (request.method == 'PUT' && put != null) {
                return _call(put, request);
            } else if (request.method == 'DELETE' && delete != null) {
                return _call(delete, request);
            } else {
                return new Response("Method not allowed", status: Status.ERROR, statusCode: HttpStatus.METHOD_NOT_ALLOWED);
            }
        }).catchError((e) {
            if (e is AuthorizationException) {
                return new Response(e.toString(), status: Status.ERROR, statusCode: HttpStatus.FORBIDDEN);
            } else {
                throw e;
            }
        });
    }

    Future<Response> _call(Processor processor, Request request) => new Future(() => processor(request));
}

class Request {
    final String method;
    final String path;
    Map<String, String> queryParameters = {};
    Map<String, String> urlParameters = {};
    final Map<String, String> preprocessorData = {};

    var body;

    Request(this.method, this.path);
}

/// A [JSend][] style response body with a HTTP status code added.
///
/// [JSEND]: http://labs.omniti.com/labs/jsend
class Response {
    final Status status;
    final int statusCode;
    final Object data;

    Response(this.data, {this.status: Status.SUCCESS, this.statusCode: 200});

    /// Returns a JSON representation of the response.
    String toString() {
        if (status == Status.ERROR) {
            return JSON.encode({
                "status" : status.value,
                "statusCode" : statusCode,
                "message" : data,
            });
        } else {
            return JSON.encode({
                "data" : data,
                "status" : status.value,
                "statusCode" : statusCode,
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
