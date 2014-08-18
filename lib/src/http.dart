part of RestLibrary;

typedef WebSocketUpgradeRequestCallback(HttpRequest request);

class HttpTransport {
    RestServer _server;
    
    List<String> _clientRoutes = [];
    bool _staticJailRoot;
    String _staticPath;
    VirtualDirectory _staticServer;

    WebSocketUpgradeRequestCallback _webSocketCallback;
    String _webSocketPath;

    /// Bind the server to a socket and start handling requests.
    HttpTransport(this._server, {address: null, int port: 80}) {
        address = address != null ? address : InternetAddress.LOOPBACK_IP_V4;

        HttpServer.bind(address, port).then((server) {
            server.listen(_handle);
        });
    }

    /// Supply a directory to serve static files from
    void static(String path, {bool jailRoot: true, List<String> clientRoutes}) {
        _staticPath = path;
        _staticJailRoot = jailRoot;
        if (clientRoutes is List) _clientRoutes = clientRoutes;

        _staticServer = new VirtualDirectory(path)
            ..allowDirectoryListing = true
            ..followLinks = true
            ..jailRoot = jailRoot
            ..errorPageHandler = _send404;

        _staticServer.directoryHandler = (Directory dir, HttpRequest request) {
            var filePath = '${dir.path}${Platform.pathSeparator}index.html';
            var file = new File(filePath);
            _staticServer.serveFile(file, request);
        };
    }

    void webSocket(String path, WebSocketUpgradeRequestCallback callback) {
        _webSocketPath = path;
        _webSocketCallback = callback;
    }

    /// Is called internally, there are usually no reason to call this manually.
    ///
    /// Will call the matching route if it exists, else it will return a 404 Not Found Error.
    /// If any uncaught exception is caught it will return a 500 Internal server Error.
    void _handle(HttpRequest request) {
        _setHeaders(request);
        var clientRoute;
        
        // Don't allow navigating up paths.
        if (request.uri.path.split('/').contains('..')) {
            _send404(request);
        } else if (_webSocketPath != null && request.uri.path == _webSocketPath && WebSocketTransformer.isUpgradeRequest(request)) {
            _webSocketCallback(request);
        } else if (_staticServer != null && (clientRoute = _checkClientRoute(request)) != null) {
            _serveClientRoute(request, clientRoute);
        } else {
            request.toList().then((List<List<int>> buffer) {
                var body = UTF8.decode(buffer.expand((i) => i).toList());
                
                if (body.isEmpty) {
                    return null;
                } else {
                    return JSON.decode(body);
                }
            }).then((body) {
                var restRequest = new Request(request.method, request.uri.path)
                    ..queryParameters = request.uri.queryParameters
                    ..body = body;
                _server.handle(restRequest).then((response) {
                    if (response == null) {
                        if (_staticServer != null) {
                            _staticServer.serveRequest(request);
                        } else {
                            _send404(request);
                        }
                    } else {
                        request.response
                            ..statusCode = response.statusCode
                            ..write(response)
                            ..close();
                    }
                });
            });
        }
    }

    String _checkClientRoute(HttpRequest request) =>
            _clientRoutes.firstWhere((alias) => request.uri.path.startsWith(alias), orElse: () => null);
    
    void _serveClientRoute(HttpRequest request, String clientRoute) {
        var file = request.uri.path.substring(clientRoute.length);
        file = file.isNotEmpty ? file.replaceFirst(new RegExp(r'^\/'), '') : 'index.html';
        _staticServer.serveFile(new File('$_staticPath${Platform.pathSeparator}$file'), request);
    }

    void _send404(HttpRequest request) {
        _setHeaders(request);

        request.response
            ..statusCode = HttpStatus.NOT_FOUND
            ..write(new Response("Not found", status: Status.ERROR, statusCode: 404))
            ..close();
    }

    void _send500(HttpRequest request, e) {
        _setHeaders(request);

        request.response
            ..statusCode = HttpStatus.INTERNAL_SERVER_ERROR
            ..write(new Response(e.toString(), status: Status.ERROR, statusCode: 404))
            ..close();
    }

    void _setHeaders(HttpRequest request) {
        request.response
            ..headers.set('Access-Control-Allow-Origin', '*')
            ..headers.contentType = new ContentType('application', 'json', charset: 'utf-8');
    }
}