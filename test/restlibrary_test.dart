import 'dart:convert';
import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:RestLibrary/restlibrary.dart';


void main() {
    unittestConfiguration.timeout = new Duration(seconds: 3);

    group('Server handle', () {
        test('unregisterd route', () {
            var server = new RestServer();

            server.handle(new Request('GET', '/')).then(expectAsync((response) {
                expect(response.toString(), equals('{"status":"error","statusCode":404,"message":"Not found"}'));
            }));
        });

        test('uncaught error', () {
            var server = new RestServer()
                ..route(new Route('/test')
                    ..get = (_) => throw new Exception());

            server.handle(new Request('GET', '/test')).then(expectAsync((response) {
                expect(response.toString(), equals('{"status":"error","statusCode":500,"message":"Exception"}'));
            }));
        });
    });

    group('Server and Route, handle preprocessors', () {
        var authFailureProcessor = (_) => throw new AuthorizationException('fail', 'Will always fail.');

        expectNoCall(_) => fail('Wrong callback called');

        test('adding', () {
            var server = new RestServer()
                ..route(new Route('/first')
                    ..get = expectAsync((_) => new Response('')))
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/second')
                    ..get = expectNoCall);


            server.handle(new Request('GET', '/first')).then(expectAsync((response) {
                expect(response.toString(), equals('{"data":"","status":"success","statusCode":200}'));
            }));

            server.handle(new Request('GET', '/second')).then(expectAsync((response) {
                expect(response.toString(), equals('{"status":"error","statusCode":403,"message":"Authorization error (fail): Will always fail."}'));
            }));
        });

        test('removing', () {
            var server = new RestServer()
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/first')
                    ..get = expectNoCall)
                ..removePreprocessor(authFailureProcessor)
                ..route(new Route('/second')
                    ..get = expectAsync((_) => new Response('')));

            server.handle(new Request('GET', '/first')).then(expectAsync((response) {
                expect(response.toString(), equals('{"status":"error","statusCode":403,"message":"Authorization error (fail): Will always fail."}'));
            }));


            server.handle(new Request('GET', '/second')).then(expectAsync((response) {
                expect(response.toString(), equals('{"data":"","status":"success","statusCode":200}'));
            }));
        });

        test('clearing', () {
            var server = new RestServer()
                ..preprocessor(authFailureProcessor)
                ..route(new Route('/first')
                    ..get = expectNoCall)
                ..clearAllPreprocessors()
                ..route(new Route('/second')
                    ..get = expectAsync((_) => new Response('')));

            server.handle(new Request('GET', '/first')).then(expectAsync((response) {
                expect(response.toString(), equals('{"status":"error","statusCode":403,"message":"Authorization error (fail): Will always fail."}'));
            }));


            server.handle(new Request('GET', '/second')).then(expectAsync((response) {
                expect(response.toString(), equals('{"data":"","status":"success","statusCode":200}'));
            }));
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
        expect(route.extractUrlParameters('/ten/10'), equals({'a': 'ten', 'b': '10'}));
    });

    group('Route handle request', () {
        var request;

        expectNoCall(_) {
            fail('Wrong callback called');
        }

        test('get', () {
            request = new Request('GET', '/');

            new Route('/')
                ..get = expectAsync((_) {})
                ..post = expectNoCall
                ..put = expectNoCall
                ..delete = expectNoCall
                ..handle(request);
        });

        test('post', () {
            request = new Request('POST', '/');

            new Route('/')
                ..get = expectNoCall
                ..post = expectAsync((_) {})
                ..put = expectNoCall
                ..delete = expectNoCall
                ..handle(request);
        });

        test('put', () {
            request = new Request('PUT', '/');

            new Route('/')
                ..get = expectNoCall
                ..post = expectNoCall
                ..put = expectAsync((_) {})
                ..delete = expectNoCall
                ..handle(request);
        });

        test('delete', () {
            request = new Request('DELETE', '/');

            new Route('/')
                ..get = expectNoCall
                ..post = expectNoCall
                ..put = expectNoCall
                ..delete = expectAsync((_) {})
                ..handle(request);
        });

        test('non supported method', () {
            new Route('/').handle(request).then((response) {
                expect(JSON.decode(response.toString()), equals({
                    'status': 'error',
                    'statusCode': HttpStatus.METHOD_NOT_ALLOWED,
                    'message': 'Method not allowed'
                }));
            });
        });

        test('with authorization failure', () {
            new Route('/')
                ..preprocessors = [(_) => throw new AuthorizationException('fail', 'Will always fail.')]
                ..handle(request).then(expectAsync((response) {
                    expect(JSON.decode(response.toString()), equals({
                        'status': 'error',
                        'statusCode': HttpStatus.FORBIDDEN,
                        'message': 'Authorization error (fail): Will always fail.',
                    }));
                }));
        });

        test('with with url parameters', () {
            request = new Request('GET', '/test');

            new Route('/{test}')
                ..get = expectAsync((Request r) => expect(r.urlParameters['test'], equals('test')))
                ..handle(request);
        });

        test('provides a correct Request object', () {
            request = new Request('GET', '/');

            new Route('/')
                ..get = (Request r) {
                    expect(r.body, isNull);
                    expect(r.path, equals('/'));
                    expect(r.method, equals('GET'));
                    expect(r.preprocessorData, equals({}));
                    expect(r.queryParameters, equals({}));
                    expect(r.urlParameters, equals({}));
                }
                ..handle(request);
        });
    });

    group('Response.toString() produces a correct result on', () {
        test('success', () {
            expect(JSON.decode(new Response('test').toString()),
            equals({'data': 'test', 'status': 'success', 'statusCode': HttpStatus.OK}));
        });

        test('fail', () {
            expect(JSON.decode(new Response(1, status: Status.FAIL, statusCode: HttpStatus.BAD_REQUEST).toString()),
            equals({'data': 1, 'status': 'fail', 'statusCode': HttpStatus.BAD_REQUEST}));
        });

        test('error', () {
            expect(JSON.decode(new Response([1, 2, 3], status: Status.ERROR, statusCode: HttpStatus.INTERNAL_SERVER_ERROR).toString()),
            equals({'status': 'error', 'statusCode': HttpStatus.INTERNAL_SERVER_ERROR, 'message': [1, 2, 3]}));
        });
    });
}
