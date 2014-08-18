import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:unittest/unittest.dart';

main() {
    unittestConfiguration.timeout = new Duration(seconds: 3);
    
    group('Example E2E test', () {
        var host = 'http://127.0.0.1:8080';

        test('Hello Get', () {
            http.get("$host/hello").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Get with name parameter', () {
            http.get("$host/hello?name=Foo").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Post', () {
            http.post("$host/hello").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Post with name parameter', () {
            http.post("$host/hello", body: '"Foo"').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Get with url parameter', () {
            http.get("$host/hello/Foo").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Json', () {
            http.post("$host/json", body: '{}').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Json with name parameter', () {
            http.post("$host/json", body: '{"name":"Foo"}').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Json PUT with name parameter', () {
            http.put("$host/json", body: '{"name":"Foo"}').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Get index.html', () {
            var excpectation = expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals('''
<!DOCTYPE html>
<html>
    <head lang="en">
        <meta charset="UTF-8">
        <title>RestLibrary</title>
        <link rel="stylesheet" href="style.css" />
    </head>
    <body>
        <h1>Hello, World!</h1>
    </body>
</html>
'''));
            }, count: 4);
            http.get("$host/").then(excpectation);
            http.get("$host/index.html").then(excpectation);
            http.get("$host/client").then(excpectation);
            http.get("$host/client/index.html").then(excpectation);
        });

        test('Get style.css', () {
            var excpectation = expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals('''
h1 {
    font-family: Helvetica Neue, Helvetica, Arial, sans-serif;
    color: #333;
}
'''));
            }, count: 2);
            http.get("$host/style.css").then(excpectation);
            http.get("$host/client/style.css").then(excpectation);
        });

        test('Unspecified route', () {
            http.get("$host/unspecified").then(expectAsync((response) {
                expect(response.statusCode, equals(404));
                expect(response.body, equals(JSON.encode({'status': 'error', 'statusCode': 404, 'message': 'Not found'})));
            }));
        });

        test('Unspecified method', () {
            http.put("$host/hello").then(expectAsync((response) {
                expect(response.statusCode, equals(405));
                expect(response.body, equals(JSON.encode({'status': 'error', 'statusCode': 405, 'message': 'Method not allowed'})));
            }));
        });

        test('Hello private', () {
            http.get("$host/private?password=secret").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello Get with name parameter', () {
            http.get("$host/private?password=secret&name=Foo").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success', 'statusCode': 200})));
            }));
        });

        test('Hello private without password', () {
            http.get("$host/private").then(expectAsync((response) {
                expect(response.statusCode, equals(403));
                expect(response.body, equals(JSON.encode({
                    "status": "error",
                    "statusCode": 403,
                    "message": "Authorization error (Wrong password): The password is secret"
                })));
            }));
        });
    });
}
