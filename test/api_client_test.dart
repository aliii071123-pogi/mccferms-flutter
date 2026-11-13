import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mcc_ferms_flutter/api_client.dart';
import 'package:mcc_ferms_flutter/ferms_models.dart';
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

  test(
    'student reservations are owner-filtered before reaching the UI',
    () async {
      final client = FermsApiClient(
        baseUrl: 'https://ferms.example.test',
        token: 'student-a-token',
        client: MockClient(
          (_) async => http.Response(
            '{"data":['
            '{"id":1,"user_id":7,"purpose":"Student A request","status":"pending"},'
            '{"id":2,"user_id":8,"purpose":"Student B private request","status":"pending"}'
            '],"current_page":1,"last_page":1}',
            200,
          ),
        ),
      );
      final repository = FermsRepository(client);
      final studentA = FermsUser.fromJson({'id': 7, 'role': 'student'});

      final reservations = await repository.reservations(user: studentA);

      expect(reservations, hasLength(1));
      expect(reservations.single.requesterId, '7');
      expect(reservations.single.purpose, 'Student A request');
    },
  );

  test('requests calendar and managed organization choices', () async {
    final requests = <http.Request>[];
    final client = FermsApiClient(
      baseUrl: 'https://ferms.example.test',
      token: 'test-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.url.path.endsWith('/calendar')
              ? '{"data":[{"facility":"Auditorium",'
                    '"starts_at":"2026-11-20T08:00:00+08:00",'
                    '"ends_at":"2026-11-20T10:00:00+08:00",'
                    '"status":"pending"}]}'
              : '{"data":[{"id":1,"name":"Student Council"}]}',
          200,
        );
      }),
    );
    final repository = FermsRepository(client);

    final calendar = await repository.calendar(DateTime(2026, 11));
    final organizations = await repository.organizations();

    expect(requests.first.url.queryParameters, {'month': '2026-11'});
    expect(requests.first.headers['authorization'], 'Bearer test-token');
    expect(calendar.single.displayStatus, 'Pending');
    expect(organizations.single.name, 'Student Council');
  });

  test(
    'suspension 403 invokes session handler and uses a safe message',
    () async {
      var suspensionHandled = false;
      final client = FermsApiClient(
        baseUrl: 'https://ferms.example.test',
        token: 'test-token',
        onAccountSuspended: (_) async {
          suspensionHandled = true;
        },
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Sensitive account-specific information"}',
            403,
          ),
        ),
      );

      await expectLater(
        client.get('/api/v1/calendar'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('account is suspended'),
          ),
        ),
      );
      expect(suspensionHandled, isTrue);
    },
  );

  test(
    'uses the documented recommendation and feedback API requests',
    () async {
      final requests = <http.Request>[];
      final client = FermsApiClient(
        baseUrl: 'https://ferms.example.test',
        token: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"data":{"id":12}}', 201);
        }),
      );
      final repository = FermsRepository(client);
      final student = FermsUser.fromJson({'id': 7, 'role': 'student'});

      await repository.recommendReservation('12');
      await repository.submitFeedback(
        user: student,
        rating: 5,
        comment: '  Great service. ',
        anonymous: true,
      );

      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/api/v1/reservations/12/recommend');
      expect(requests[0].body, isEmpty);
      expect(requests[0].headers['authorization'], 'Bearer test-token');
      expect(requests[1].url.path, '/api/v1/feedback');
      expect(jsonDecode(requests[1].body), {
        'rating': 5,
        'comment': 'Great service.',
        'anonymous': true,
      });
    },
  );

  test(
    'blocks non-student anonymity and unauthorized feedback listing',
    () async {
      var requestCount = 0;
      final client = FermsApiClient(
        baseUrl: 'https://ferms.example.test',
        client: MockClient((_) async {
          requestCount++;
          return http.Response('{"data":[]}', 200);
        }),
      );
      final repository = FermsRepository(client);
      final staff = FermsUser.fromJson({'id': 8, 'role': 'staff'});

      await expectLater(
        repository.submitFeedback(
          user: staff,
          rating: 4,
          comment: 'Useful.',
          anonymous: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.feedback(user: staff),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
      expect(requestCount, 0);
    },
  );

  test('loads administrator feedback by page from Laravel paginator', () async {
    late http.Request captured;
    final client = FermsApiClient(
      baseUrl: 'https://ferms.example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"data":[{"id":3,"rating":4,"comment":"Helpful",'
          '"anonymous":false,"created_at":"2026-11-20T08:00:00Z"}],'
          '"current_page":2,"last_page":3,"per_page":12,"total":25}',
          200,
        );
      }),
    );
    final result = await FermsRepository(client).feedback(
      user: FermsUser.fromJson({'id': 9, 'role': 'super_admin'}),
      page: 2,
    );

    expect(captured.url.queryParameters, {'page': '2'});
    expect(result.items.single.comment, 'Helpful');
    expect(result.currentPage, 2);
    expect(result.lastPage, 3);
    expect(result.total, 25);
    expect(result.hasPreviousPage, isTrue);
    expect(result.hasNextPage, isTrue);
  });
}
