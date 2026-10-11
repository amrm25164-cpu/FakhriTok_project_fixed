# FakhriTok — Flutter app + Flask backend

FakhriTok is an Arabic-first short-video application project. It now includes a Flutter client and a Flask API backend that supports real multi-user data when the backend is deployed and configured.

## Included in this project

### Flutter client
- Full-screen vertical video feed and playback.
- Local demo feed when the backend is unavailable or has no videos.
- Local video selection and playback.
- Backend URL configuration in Profile.
- Registration/login UI connected to the backend API.
- Video upload to the backend for authenticated users.
- Server-backed likes, saves, comments, and follows for server videos when logged in.
- Local likes/comments/saves for demo videos.
- Search UI and profile/inbox screens.
- Arabic-first UI and dark theme.

### Flask backend (`backend/`)
- Registration/login with password hashing and signed JWTs.
- Profiles and profile editing.
- Video upload and streaming.
- Paginated public feed.
- Likes, comments, follows, saves.
- User search, notifications, reports, and block list.
- SQLite for development, plus a Dockerfile for deployment.

## Important limits

This is a substantial working project foundation, but it is **not yet a production-equivalent TikTok clone**. It does not include deployed hosting, production-grade recommendation ranking, private messaging, push notifications, video transcoding/CDN, admin moderation dashboard, password reset/email verification, or automated abuse detection. The backend must be deployed and hardened before real public use. The Flutter source has not been compiled in this environment because Flutter SDK is unavailable here, so build success is not claimed.

## Run the backend

```bash
cd backend
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# Linux/macOS/Termux: source .venv/bin/activate
pip install -r requirements.txt
export FAKHRITOK_SECRET_KEY="replace-with-a-long-random-secret"
python app.py
```

Health check: `http://127.0.0.1:8000/api/health`

For a physical Android phone, the API base URL must be the server's LAN IP (for example `http://192.168.1.10:8000`) if both devices share the same Wi-Fi. `localhost` on the phone points to the phone, not another computer. Android emulator default `http://10.0.2.2:8000` points to the host machine.

## Run the Flutter app

Open this folder as a Flutter project in Klencod IDE. If Android scaffolding is missing, run in the project directory:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
```

In the app, open **Profile → Connection to server**, enter the backend URL, and save. Then open **Profile → Account** to register or log in. Once signed in, video uploads go to the backend. Without login/server, uploads stay on the device and demo feed remains available.

If Android blocks local HTTP traffic during development, enable cleartext traffic only for development in the Android app manifest. For public deployment, use HTTPS instead.

## Build APK

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

Expected APK path: `build/app/outputs/flutter-apk/app-release.apk`.

## Production requirements before public launch

- Deploy backend behind HTTPS and set a strong secret using your host's secret manager.
- Replace SQLite/local disk storage with PostgreSQL and object storage/CDN for public scale.
- Add rate limiting, upload quotas, media scanning, moderation tooling, backups, deletion/privacy workflows, email verification and password recovery.
- Implement push notification delivery and private messaging if needed.
- Configure and test Android network security and media permissions.
- Do not expose database files, server secrets, or development credentials.
