import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:unittest/unittest.dart';

main() {
    group('Example E2E test', () {
        var host = 'http://127.0.0.1:8080';

        test('Hello Get', () {
            http.get("$host/hello").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success'})));
            }));
        });

        test('Hello Get with name parameter', () {
            http.get("$host/hello?name=Foo").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success'})));
            }));
        });

        test('Hello Post', () {
            http.post("$host/hello").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success'})));
            }));
        });

        test('Hello Post with name parameter', () {
            http.post("$host/hello", body: 'Foo').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success'})));
            }));
        });

        test('Hello Get with url parameter', () {
            http.get("$host/hello/Foo").then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success'})));
            }));
        });

        test('Hello Json', () {
            http.post("$host/json", body: '{}').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, World!', 'status': 'success'})));
            }));
        });

        test('Hello Json with name parameter', () {
            http.post("$host/json", body: '{"name":"Foo"}').then(expectAsync((response) {
                expect(response.statusCode, equals(200));
                expect(response.body, equals(JSON.encode({'data': 'Hello, Foo!', 'status': 'success'})));
            }));
        });
    });
}
