# Flutter API Connection

FERMS keeps PostgreSQL in Supabase. Flutter clients should call the Laravel API, not the Supabase Data API. The Laravel connection uses the server-side Supabase database role; `anon` and `authenticated` Data API roles have no access to FERMS tables.

## Microsoft Sign-In

1. Open `GET {API_BASE_URL}/auth/microsoft?client=mobile` in the system browser.
2. After Microsoft sign-in, Laravel redirects to the configured `FERMS_MOBILE_CALLBACK_URI` with a short-lived `code` query parameter.
3. Exchange that code once:

```http
POST {API_BASE_URL}/api/v1/auth/exchange
Accept: application/json
Content-Type: application/json

{"code":"<one-time-code>"}
```

The response contains `token`, `expires_at`, and `user`. Store the bearer token in the platform's secure storage. Codes expire after three minutes and cannot be reused. Tokens expire after `FERMS_API_TOKEN_DAYS` (30 days by default).

Flutter opens `{API_BASE_URL}/auth/microsoft?client=web` in a browser and uses `client=mobile` in the installed app. Laravel must send successful web sign-ins back to the configured Flutter origin over HTTPS with the one-time `code` query parameter. The app exchanges the code at `/api/v1/auth/exchange`; allow the deployed app origin in `FERMS_CORS_ALLOWED_ORIGINS`.

If the student's organization profile is incomplete, reservation endpoints return `403` with `profile_required: true`. Complete it with `PUT /api/v1/profile` and the required `organization` and `position` strings.

## API Endpoints

Send `Accept: application/json` and `Authorization: Bearer <token>` on authenticated requests.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/api/v1/auth/exchange` | Exchange a mobile sign-in code for a token |
| GET | `/api/v1/me` | Current account and role |
| DELETE | `/api/v1/auth/session` | Revoke the current token |
| GET | `/api/v1/dashboard` | Dashboard counts |
| PUT | `/api/v1/profile` | Update a student's organization and position |
| GET | `/api/v1/organizations` | Managed organization choices for profile selection |
| GET | `/api/v1/facilities` | Facilities and upcoming schedule blocks |
| GET | `/api/v1/equipment` | Equipment inventory and upcoming borrowing blocks |
| GET | `/api/v1/calendar?month=YYYY-MM` | Privacy-safe facility availability for the requested month |
| GET | `/api/v1/reservations` | Current user's requests, or all requests for staff/admin |
| POST | `/api/v1/reservations` | Create a request |
| GET | `/api/v1/reservations/{id}` | Request details |
| PUT | `/api/v1/reservations/{id}` | Edit the owner's pending request |
| DELETE | `/api/v1/reservations/{id}/cancel` | Cancel the owner's pending request |
| PUT | `/api/v1/reservations/{id}/decision` | Admin approval/rejection |
| DELETE | `/api/v1/reservations/{id}` | Admin request deletion |
| POST | `/api/v1/reservations/{id}/recommend` | Staff approval recommendation (Laravel API addition required) |
| POST | `/api/v1/feedback` | Submit a rating and comment (Laravel API addition required) |
| GET | `/api/v1/feedback` | Admin / IT Administrator feedback inbox (Laravel API addition required) |
| POST/PUT/DELETE | `/api/v1/facilities[/{id}]` | Staff+ facility management |
| POST/PUT/DELETE | `/api/v1/equipment[/{id}]` | Staff+ equipment management |

Organization choices return `{"data":[{"id":1,"name":"..."}]}`. The mobile app submits the selected managed organization name through the existing profile API. Although the UI offers “Other (not listed),” the current `PUT /api/v1/profile` contract accepts only a name in the managed organization catalog; the app therefore requires a managed selection before saving. To enable custom names, extend `PUT /api/v1/profile` with an optional `custom_organization` string for the “Other” selection, validate it as required only for that selection, and persist it as the profile's organization so `/api/v1/me` returns it. The backend must explicitly decide whether custom names remain profile-only or are added to the managed organization catalog; the Flutter client does not assume either behavior.

Reservation creation uses per-day schedule blocks; do not send the legacy single `date`, `start_time`, and `end_time` shape:

```json
{
  "facility_id": 1,
  "duration_days": 2,
  "days": [
    {"date":"2026-11-20","start_time":"08:00","end_time":"17:00"},
    {"date":"2026-11-21","start_time":"08:00","end_time":"17:00"}
  ],
  "pax": 50,
  "purpose": "Event name",
  "description": "Event details",
  "equipment": {"3": 2}
}
```

`facility_id` is nullable for equipment-only requests. `duration_days` must be 1–7 and equal the number of `days` entries. Dates use `YYYY-MM-DD`, are today or later, and must be strictly increasing. Times use `HH:mm` Manila local time, from 08:00 through 20:00, with each end later than its start. At least one facility or positive equipment quantity is required. `pax`, purpose, description, and requested equipment quantities remain required according to existing validation. Responses include `data.schedules`; show those individual blocks for a user's own request details. Validation failures return `422` with field errors.

Facility time conflicts return `422` with a `facility_conflict` validation error. Pending, recommended, and approved requests block overlapping facility slots, and each event day is checked independently. The app presents a generic conflict message and directs users to facility staff; never expose another requester's identity, organization/institute, or activity in shared calendar or conflict UI.

The authenticated calendar response is `{"data":[{"facility":"Facility name","starts_at":"ISO timestamp","ends_at":"ISO timestamp","status":"pending|approved"}]}`. It contains only facility name, date/time, and status; if a reservation has status `recommended`, return the generic availability status `pending`. Render `pending` as “Pending” and `approved` as “Booked.” Do not add requester, organization/institute, purpose/activity, or other reservation details to this endpoint or UI.

Equipment may include optional `category`, `staff_in_charge`, quantity/availability, notes, and schedule blocks. Categories may be null; the app filters the loaded catalog locally and includes an “Uncategorized” choice.

An authenticated API `403` without `profile_required: true` denotes a suspended account; clear the local session and show a suspended/signed-out state rather than retrying as a network error. `403` with `profile_required: true` continues to mean the student profile is incomplete.

There are no documented mobile API endpoints for super-admin user suspension/deletion or organization-choice create/delete. Those operations remain web-only; do not add mobile CRUD requests until the backend publishes and implements those API contracts.

Use `GET /api/v1/reservations?view=history` for completed/closed history; the default lists upcoming and pending requests. Admin review payload: `{"status":"approved"}` or `{"status":"rejected"}`.

The checked Laravel repository snapshot was inspected before these client calls were added. Its current `routes/api.php` does not contain mobile recommendation or feedback routes, `ReservationController` still marks only `pending` and `approved` as busy, and the inspected `routes/web.php` snapshot does not contain the described web recommendation route either. The Flutter workspace does not include the Laravel source, so no backend edits or migrations can be made here. These mobile features will return 404 until Laravel implements the following contracts; verify the web route in the backend branch/deployment as well.

### Staff reservation recommendation

Add `POST /api/v1/reservations/{reservation}/recommend` inside the `auth:sanctum`, `account.active`, and `role:staff` middleware. It accepts no decision payload and only accepts a reservation whose current status is `pending`. It sets `status: "recommended"`, `recommended_by` to the authenticated staff user ID, and `recommended_at` to the server timestamp; return `{"data": <reservation>}` including those fields and, if available, `recommender: {"id": ..., "name": ...}`. Admins / IT Administrators keep the only final decision route. Update that endpoint to accept both `pending` and `recommended` requests and only `approved` or `rejected` decisions; responses include `reviewed_at` and `reviewer` data. Add `recommended` to all facility/equipment busy-status sets, and include it in upcoming reservation lists and dashboard pending counts.

For authorized reservation list/detail data, include `reviewed_at`, `reviewer` (or `reviewer_name`), `recommended_by`, `recommended_at`, and `recommender` (or `recommender_name`). The inspected Laravel list eager-loads the requester but not the reviewer/recommender; add the needed eager loads/serialization. Preserve the existing student `user_id` filter for list and detail authorization. Flutter also filters student list results by `user_id`/nested `user.id` and fails closed if owner ID is absent, but that is only defense in depth—the server must not return another student's request or metadata in the first place.

### Feedback

Add authenticated, active-account routes:

- `POST /api/v1/feedback` for any signed-in role, validating `rating` as required integer `1..5`, `comment` as required non-empty string (maximum 5000 characters), and optional `anonymous` boolean.
- `GET /api/v1/feedback?page={page}` under `role:admin,super_admin` only, using Laravel's standard paginator response.

The submission JSON is `{"rating": 1, "comment": "...", "anonymous": false}`. Accept `anonymous: true` only for students, persist no user association (including no user ID in the API response), and reject `anonymous: true` for every other role. Flutter sends only those three fields; it does not send an ID or retain anonymous sender details in feedback state. A created record uses `{"data": {"id": ..., "rating": ..., "comment": ..., "anonymous": ..., "created_at": ..., "user": ...}}`, with `user: null` for anonymous feedback. The list follows Laravel paginator shape: `{"data": [...], "current_page": 1, "last_page": 1, "per_page": 12, "total": 0, ...}`. Do not add feedback to dashboard, reservation, or other general API payloads, and never permit Staff or Students to read the feedback list.

Account-management APIs are also absent from the mobile route list. The app therefore does not expose mobile account CRUD; keep account management limited to IT Administrators in the web client until the backend publishes protected mobile endpoints. The server remains responsible for enforcing the maximum of three IT Administrators.

The web routes contain IT Administrator account management (`/accounts`), but the inspected API route list has no account API. Flutter does not expose account CRUD. If a mobile account screen is added later, publish Sanctum-protected account list/create/update/suspend/delete routes under `role:super_admin` only, include a server-enforced maximum of three IT Administrators on create/role-change, and return a clear `422` validation error when at capacity. The app-side `canCreateItAdministrator` predicate is presentation guidance only and is not an authorization boundary.

The reservation calendar remains a separate privacy-safe availability feed containing only facility, start/end time, and status. Do not add requester, recommendation actor, reviewer, activity, or organization details to calendar/catalog responses.

## Deployment Settings

- Register the exact callback URL `{APP_URL}/auth/microsoft/callback` in the Microsoft Entra app.
- Set `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, and `MICROSOFT_TENANT_ID` in the server environment. `FERMS_SUPERADMIN_EMAIL` identifies the bootstrap super-admin.
- Register the mobile callback scheme as an Android intent filter and iOS URL type. Set `FERMS_MOBILE_CALLBACK_URI` to that callback. Prefer verified app/universal links for production deployments.
- Set `FERMS_CORS_ALLOWED_ORIGINS` to the exact deployed Flutter Web origins (comma-separated); native mobile clients do not rely on browser CORS.
- Run `php artisan migrate --force` against the Supabase connection after deploying code. Keep `DB_CONNECTION=pgsql` and the Supabase pooler credentials; never ship Supabase service-role or database credentials in Flutter.