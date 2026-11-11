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
| GET | `/api/v1/facilities` | Facilities and upcoming schedule blocks |
| GET | `/api/v1/equipment` | Equipment inventory and upcoming borrowing blocks |
| GET | `/api/v1/reservations` | Current user's requests, or all requests for staff/admin |
| POST | `/api/v1/reservations` | Create a request |
| GET | `/api/v1/reservations/{id}` | Request details |
| PUT | `/api/v1/reservations/{id}` | Edit the owner's pending request |
| DELETE | `/api/v1/reservations/{id}/cancel` | Cancel the owner's pending request |
| PUT | `/api/v1/reservations/{id}/decision` | Admin approval/rejection |
| DELETE | `/api/v1/reservations/{id}` | Admin request deletion |
| POST/PUT/DELETE | `/api/v1/facilities[/{id}]` | Staff+ facility management |
| POST/PUT/DELETE | `/api/v1/equipment[/{id}]` | Staff+ equipment management |

Reservation creation fields are `facility_id` (nullable when borrowing equipment only), `date` (`YYYY-MM-DD`), `start_time` and `end_time` (`HH:mm`, Manila local time), `pax`, `purpose`, `description`, and `equipment` (an object mapping equipment IDs to requested quantities). At least one facility or positive equipment quantity is required. Validation failures return `422` with field errors.

Use `GET /api/v1/reservations?view=history` for completed/closed history; the default lists upcoming and pending requests. Admin review payload: `{"status":"approved"}` or `{"status":"rejected"}`.

## Deployment Settings

- Register the exact callback URL `{APP_URL}/auth/microsoft/callback` in the Microsoft Entra app.
- Set `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, and `MICROSOFT_TENANT_ID` in the server environment. `FERMS_SUPERADMIN_EMAIL` identifies the bootstrap super-admin.
- Register the mobile callback scheme as an Android intent filter and iOS URL type. Set `FERMS_MOBILE_CALLBACK_URI` to that callback. Prefer verified app/universal links for production deployments.
- Set `FERMS_CORS_ALLOWED_ORIGINS` to the exact deployed Flutter Web origins (comma-separated); native mobile clients do not rely on browser CORS.
- Run `php artisan migrate --force` against the Supabase connection after deploying code. Keep `DB_CONNECTION=pgsql` and the Supabase pooler credentials; never ship Supabase service-role or database credentials in Flutter.