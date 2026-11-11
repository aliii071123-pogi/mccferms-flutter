import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcc_ferms_flutter/api_client.dart';
import 'package:mcc_ferms_flutter/ferms_repository.dart';

void main() {
  test('sends authenticated JSON requests to the versioned API', () async {
    late http.Request captured;
    final client = FermsApiClient(
      baseUrl: 'https://ferms.example.test/',
      token: 'test-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"data":{"id":4}}', 200);
      }),
    );

    final result = await client.post('/api/v1/reservations', body: {'pax': 12});

    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://ferms.example.test/api/v1/reservations',
    );
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(captured.body), {'pax': 12});
    expect(result, {
      'data': {'id': 4},
    });
  });

  test('keeps Laravel validation errors and profile requirements', () async {
    final client = FermsApiClient(
      baseUrl: 'https://ferms.example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"message":"Profile required.","profile_required":true,'
          '"errors":{"organization":["Required."]}}',
          403,
        ),
      ),
    );

    await expectLater(
      client.get('/api/v1/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.profileRequired, 'profileRequired', true)
            .having((error) => error.errors['organization'], 'errors', [
              'Required.',
            ]),
      ),
    );
  });

  test('maps Laravel data envelopes and role capabilities', () async {
    final client = FermsApiClient(
      baseUrl: 'https://ferms.example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            '{"data":{"id":7,"name":"Alex Student","email":"a@mcc.edu.ph",'
            '"role":"student","organization":"Council","position":"Officer"}}',
            200,
          );
        }
        return http.Response(
          '{"data":[{"id":2,"name":"Auditorium","capacity":120}]}',
          200,
        );
      }),
    );
    final repository = FermsRepository(client);

    final user = await repository.me();
    final facilities = await repository.facilities();

    expect(user.profileIncomplete, isFalse);
    expect(user.canReviewRequests, isFalse);
    expect(facilities.single.name, 'Auditorium');
    expect(facilities.single.capacity, 120);
  });
}
