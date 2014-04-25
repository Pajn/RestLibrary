import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:unittest/mock.dart';
import 'package:RestLibrary/restlibrary.dart';

class MockHttpHeaders extends Mock implements HttpHeaders {}
class MockHttpResponse extends Mock implements HttpResponse {
    int statusCode;
    Function closed;
    HttpHeaders headers = new MockHttpHeaders();

    Future close() {
        if (closed != null) {
            closed();
        }
        return null;
    }
}
class MockHttpRequest extends Mock implements HttpRequest {
    String method;
    Uri uri;
    var response = new MockHttpResponse();
}


void main() {
    unittestConfiguration.timeout = new Duration(seconds: 3);

    group('Server handle', () {
        test('unregisterd route', () {
            var server = new RestServer()
                ..route(new Route('/test'));

            var request = new MockHttpRequest()
                ..uri = new Uri(path: '/');
            request.response.closed = () {
                expect(request.response.statusCode, equals(HttpStatus.NOT_FOUND));
            };
            server.handle(request);
        });

        test('uncaught error', () {
            var server = new RestServer()
                ..route(new Route('/test')
                    ..get = (_) => throw new Exception());

            var request = new MockHttpRequest()
                ..uri = new Uri(path: '/test')
                ..method = 'GET';
            request.response.closed = () {
                expect(request.response.statusCode, equals(HttpStatus.INTERNAL_SERVER_ERROR));
            };
            server.handle(request);
        });
    });

    group('Server and Route, handle preprocessors', () {
        var authFailureProcessor = (_) => throw new AuthorizationException('fail', 'Will always fail.');

        Future<Response> expectNoCall(_) {
            fail('Wrong callback called');
            return null;
        }

        test('adding', () {
            var server = new RestServer()
                ..route(new Route('/first')
                    ..get = expectAsync((_) {return new Future.sync(() {});}))
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/second')
                    ..get = expectNoCall);

            var request = new MockHttpRequest()
                ..uri = new Uri(path: '/first')
                ..method = 'GET';
            request.response.closed = () {
                expectAsync((_) {});
                expect(request.response.statusCode, equals(HttpStatus.OK));
            };
            server.handle(request);

            var request2 = new MockHttpRequest()
                ..uri = new Uri(path: '/second')
                ..method = 'GET';
            request2.response.closed = () {
                expectAsync((_) {});
                expect(request2.response.statusCode, equals(HttpStatus.UNAUTHORIZED));
            };
            server.handle(request2);
        });

        test('removing', () {
            var server = new RestServer()
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/first')
                    ..get = expectNoCall)
                ..removePreprocessor(authFailureProcessor)
                ..route(new Route('/second')
                    ..get = expectAsync((_) {return new Future.sync(() {});}));

            var request = new MockHttpRequest()
                ..uri = new Uri(path: '/first')
                ..method = 'GET';
            request.response.closed = () {
                expectAsync((_) {});
                expect(request.response.statusCode, equals(HttpStatus.UNAUTHORIZED));
            };
            server.handle(request);

            var request2 = new MockHttpRequest()
                ..uri = new Uri(path: '/second')
                ..method = 'GET';
            request2.response.closed = () {
                expectAsync((_) {});
                expect(request2.response.statusCode, equals(HttpStatus.OK));
            };
            server.handle(request2);
        });

        test('clearing', () {
            var server = new RestServer()
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/first')
                    ..get = expectNoCall)
                ..clearAllPreprocessors()
                ..route(new Route('/second')
                    ..get = expectAsync((_) {return new Future.sync(() {});}));

            var request = new MockHttpRequest()
                ..uri = new Uri(path: '/first')
                ..method = 'GET';
            request.response.closed = () {
                expectAsync((_) {});
                expect(request.response.statusCode, equals(HttpStatus.UNAUTHORIZED));
            };
            server.handle(request);

            var request2 = new MockHttpRequest()
                ..uri = new Uri(path: '/second')
                ..method = 'GET';
            request2.response.closed = () {
                expectAsync((_) {});
                expect(request2.response.statusCode, equals(HttpStatus.OK));
            };
            server.handle(request2);
        });
    });

    group('Route matches', () {
        test('simple url', () {
            var route = new Route('/test');
            expect(route.match('/test'), equals(true));
        });

        test('url with string parameter as default type', () {
            var route = new Route('/test/{id}');
            expect(route.match('/test/test2'), equals(true));
        });

        test('url with string parameter as specified type', () {
            var route = new Route('/test/{id:s}');
            expect(route.match('/test/test2'), equals(true));
        });

        test('url with int parameter', () {
            var route = new Route('/test/{id:i}');
            expect(route.match('/test/10'), equals(true));
            expect(route.match('/test/ten'), equals(false));
        });

        test('url with ending slash', () {
            var route = new Route('/test');
            expect(route.match('/test/'), equals(true));
        });
    });

    test('Route extract parameters', () {
        var route = new Route('/{a}/{b:i}');
        expect(route.extractParameters('/ten/10'), equals({'a': 'ten', 'b': '10'}));
    });

    group('Route handle request', () {
        var request;

        Future<Response> expectNoCall(_) {
            fail('Wrong callback called');
            return null;
        }

        setUp(() {
            request = new MockHttpRequest()..uri = new Uri(path: '/');
        });

        test('get', () {
            request.method = 'GET';

            new Route('/')
                ..get = expectAsync((_) {})
                ..post = expectNoCall
                ..put = expectNoCall
                ..delete = expectNoCall
                ..handle(request);
        });

        test('post', () {
            request.method = 'POST';

            new Route('/')
                ..get = expectNoCall
                ..post = expectAsync((_) {})
                ..put = expectNoCall
                ..delete = expectNoCall
                ..handle(request);
        });

        test('put', () {
            request.method = 'PUT';

            new Route('/')
                ..get = expectNoCall
                ..post = expectNoCall
                ..put = expectAsync((_) {})
                ..delete = expectNoCall
                ..handle(request);
        });

        test('delete', () {
            request.method = 'DELETE';

            new Route('/')
                ..get = expectNoCall
                ..post = expectNoCall
                ..put = expectNoCall
                ..delete = expectAsync((_) {})
                ..handle(request);
        });

        test('non supported method', () {
            new Route('/').handle(request).then((response) {
                expect(JSON.decode(response.toString()),
                equals({'status': 'error', 'message': 'Method not allowed'}));

                expect(request.response.statusCode, equals(HttpStatus.METHOD_NOT_ALLOWED));
            });
        });

        test('with authorization failure', () {
            new Route('/')
                ..preprocessors = [(_) => throw new AuthorizationException('fail', 'Will always fail.')]
                ..handle(request).then((response) {
                    expect(JSON.decode(response.toString()),
                    equals({'data': 'Authorization error (fail): Will always fail.', 'status': 'fail'}));

                    expect(request.response.statusCode, equals(HttpStatus.UNAUTHORIZED));
                });
        });

        test('with with url parameters', () {
            request = new MockHttpRequest()
                ..method = 'GET'
                ..uri = new Uri(path: '/test');

            new Route('/{test}')
                ..get = expectAsync((Request r) => expect(r.urlParameters['test'], equals('test')))
                ..handle(request);
        });

        test('provides a correct Request object', () {
            request.method = 'GET';

            new Route('/')
                ..get = (Request r) {
                    expect(r.httpRequest, equals(request));
                    expect(r.urlParameters, equals({}));
                }
                ..handle(request);
        });
    });

    group('Response.toString() produces a correct result on', () {
        test('success', () {
            expect(JSON.decode(new Response('test').toString()),
            equals({'data': 'test', 'status': 'success'}));
        });

        test('fail', () {
            expect(JSON.decode(new Response(1, status: Status.FAIL).toString()),
            equals({'data': 1, 'status': 'fail'}));
        });

        test('error', () {
            expect(JSON.decode(new Response([1, 2, 3], status: Status.ERROR).toString()),
            equals({'status': 'error', 'message': [1, 2, 3]}));
        });
    });
}
