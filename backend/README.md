# FakhriTok API backend (Flask + SQLite)

This backend adds real multi-user API behavior: registration/login, JWT auth, profiles, video upload/streaming, feed pagination, likes, comments, follows, saved videos, user search, notifications, reports, and blocks.

## Run locally

```bash
cd backend
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux/Termux: source .venv/bin/activate
pip install -r requirements.txt
export FAKHRITOK_SECRET_KEY="replace-this-with-a-long-random-secret"
python app.py
```

API health: `http://127.0.0.1:8000/api/health`

For a phone on the same Wi-Fi, use the computer/server LAN IP rather than `127.0.0.1`. `127.0.0.1` on Android refers to the phone itself.

## Key endpoints

- `POST /api/auth/register` JSON `{ "username":"demo_user", "email":"demo@example.com", "password":"password123" }`
- `POST /api/auth/login` JSON `{ "identity":"demo@example.com", "password":"password123" }`
- `GET /api/feed?limit=10`
- `POST /api/videos` multipart fields `video` and `caption` (Bearer token required)
- `POST /api/videos/<id>/like` (Bearer token required)
- `GET/POST /api/videos/<id>/comments`
- `POST /api/users/<user_id>/follow` (Bearer token required)
- `GET /api/users/search?q=demo`
- `GET /api/users/<user_id>`
- `POST /api/videos/<id>/save` and `GET /api/me/saved` (Bearer token required)
- `GET /api/me/notifications` (Bearer token required)
- `POST /api/reports` and `POST /api/users/<user_id>/block` (Bearer token required)

## Production hardening still required

This is a usable development backend, not a public-production deployment. Before opening it to the internet, use HTTPS, a strong secret from your host's secret manager, rate limiting, malware/content scanning, moderation/admin tooling, storage quotas, backups, and object storage/CDN for videos. Configure privacy rules for private videos (the included local upload endpoint is intended for public demo media). Add email verification/password reset and a deletion/privacy workflow. SQLite is suitable for local testing; use PostgreSQL for a larger deployment.
