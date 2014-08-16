part of RestLibrary;

class HttpTransport {
    RestServer _server;
    
    List<String> _clientRoutes = [];
    bool _staticJailRoot;
    String _staticPath;
    VirtualDirectory _staticServer;

    /// Bind the server to a socket and start handling requests.
    HttpTransport(this._server, {InternetAddress address: null, int port: 80}) {
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

    /// Is called internally, there are usually no reason to call this manually.
    ///
    /// Will call the matching route if it exists, else it will return a 404 Not Found Error.
    /// If any uncaught exception is caught it will return a 500 Internal server Error.
    void _handle(HttpRequest request) {
        _setHeaders(request);
        
        // Don't allow navigating up paths.
        if (request.uri.path.split('/').contains('..')) {
            _send404(request);
        } else if (_staticServer != null && _checkClientRoute(request)) {
            _serveClientRoute(request);
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
                    if (_staticServer != null && response.statusCode == HttpStatus.NOT_FOUND) {
                        _staticServer.serveRequest(request);
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

    bool _checkClientRoute(HttpRequest request) => _clientRoutes.any((alias) => request.uri.path.startsWith(alias));
    
    void _serveClientRoute(HttpRequest request) =>
        _staticServer.serveFile(new File('$_staticPath${Platform.pathSeparator}index.html'), request);

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