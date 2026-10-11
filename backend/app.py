import os, re, sqlite3, uuid, datetime, mimetypes
from functools import wraps
from pathlib import Path
from flask import Flask, request, jsonify, g, send_from_directory
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import jwt

ROOT = Path(__file__).resolve().parent
DB_PATH = os.environ.get('FAKHRITOK_DB', str(ROOT / 'fakhritok.db'))
UPLOAD_DIR = Path(os.environ.get('FAKHRITOK_UPLOADS', str(ROOT / 'uploads')))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
SECRET = os.environ.get('FAKHRITOK_SECRET_KEY')
if not SECRET:
    # Development fallback only. Set a long random FAKHRITOK_SECRET_KEY in production.
    SECRET = 'development-only-change-this-secret-before-deployment'
MAX_UPLOAD_MB = int(os.environ.get('MAX_UPLOAD_MB', '150'))
ALLOWED_EXTENSIONS = {'.mp4', '.mov', '.m4v', '.webm'}

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = MAX_UPLOAD_MB * 1024 * 1024
CORS(app)

SCHEMA = '''
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, email TEXT UNIQUE NOT NULL,
 password_hash TEXT NOT NULL, bio TEXT NOT NULL DEFAULT '', avatar_url TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS videos (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL, caption TEXT NOT NULL DEFAULT '',
 filename TEXT NOT NULL, created_at TEXT NOT NULL, visibility TEXT NOT NULL DEFAULT 'public',
 views INTEGER NOT NULL DEFAULT 0, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS likes (
 user_id TEXT NOT NULL, video_id TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(user_id, video_id), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS comments (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL, video_id TEXT NOT NULL, body TEXT NOT NULL,
 created_at TEXT NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS follows (
 follower_id TEXT NOT NULL, followed_id TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(follower_id, followed_id), CHECK(follower_id <> followed_id),
 FOREIGN KEY(follower_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(followed_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS saved_videos (
 user_id TEXT NOT NULL, video_id TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(user_id, video_id), FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS notifications (
 id TEXT PRIMARY KEY, recipient_id TEXT NOT NULL, actor_id TEXT NOT NULL,
 kind TEXT NOT NULL, video_id TEXT, created_at TEXT NOT NULL, is_read INTEGER NOT NULL DEFAULT 0,
 FOREIGN KEY(recipient_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(actor_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS reports (
 id TEXT PRIMARY KEY, reporter_id TEXT NOT NULL, video_id TEXT, reported_user_id TEXT,
 reason TEXT NOT NULL, details TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,
 FOREIGN KEY(reporter_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE SET NULL,
 FOREIGN KEY(reported_user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS blocks (
 blocker_id TEXT NOT NULL, blocked_id TEXT NOT NULL, created_at TEXT NOT NULL,
 PRIMARY KEY(blocker_id, blocked_id), CHECK(blocker_id <> blocked_id),
 FOREIGN KEY(blocker_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(blocked_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_videos_created ON videos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_video ON comments(video_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id, created_at DESC);
'''

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def db():
    if 'db' not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute('PRAGMA foreign_keys = ON')
    return g.db

@app.teardown_appcontext
def close_db(_exc):
    conn = g.pop('db', None)
    if conn is not None:
        conn.close()

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)
    conn.commit(); conn.close()

@app.before_request
def ensure_db():
    if not getattr(app, '_db_initialized', False):
        init_db(); app._db_initialized = True

def user_public(row):
    return {'id': row['id'], 'username': row['username'], 'bio': row['bio'], 'avatarUrl': row['avatar_url'], 'createdAt': row['created_at']}

def token_for(user_id):
    return jwt.encode({'sub': user_id, 'iat': datetime.datetime.now(datetime.timezone.utc), 'exp': datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30)}, SECRET, algorithm='HS256')

def auth_required(fn):
    @wraps(fn)
    def wrapped(*args, **kwargs):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return jsonify(error='authentication_required'), 401
        try:
            payload = jwt.decode(header[7:], SECRET, algorithms=['HS256'])
            row = db().execute('SELECT * FROM users WHERE id=?', (payload['sub'],)).fetchone()
            if row is None: raise ValueError('missing user')
            g.user = row
        except Exception:
            return jsonify(error='invalid_or_expired_token'), 401
        return fn(*args, **kwargs)
    return wrapped

def blocked_pair_sql(user_id):
    return '''NOT EXISTS (SELECT 1 FROM blocks b WHERE
       (b.blocker_id=? AND b.blocked_id=videos.user_id) OR
       (b.blocker_id=videos.user_id AND b.blocked_id=?))'''

def video_json(row, viewer_id=None):
    conn = db()
    uid = row['user_id']
    likes = conn.execute('SELECT COUNT(*) n FROM likes WHERE video_id=?', (row['id'],)).fetchone()['n']
    comments = conn.execute('SELECT COUNT(*) n FROM comments WHERE video_id=?', (row['id'],)).fetchone()['n']
    user = conn.execute('SELECT username, avatar_url FROM users WHERE id=?', (uid,)).fetchone()
    liked = bool(viewer_id and conn.execute('SELECT 1 FROM likes WHERE user_id=? AND video_id=?', (viewer_id, row['id'])).fetchone())
    saved = bool(viewer_id and conn.execute('SELECT 1 FROM saved_videos WHERE user_id=? AND video_id=?', (viewer_id, row['id'])).fetchone())
    base = request.host_url.rstrip('/')
    return {'id': row['id'], 'userId': uid, 'username': user['username'] if user else 'unknown',
            'avatarUrl': user['avatar_url'] if user else '', 'caption': row['caption'],
            'videoUrl': f'{base}/uploads/{row["filename"]}', 'createdAt': row['created_at'],
            'likes': likes, 'comments': comments, 'views': row['views'], 'liked': liked,
            'saved': saved, 'visibility': row['visibility']}

@app.get('/api/health')
def health():
    return jsonify(status='ok', service='FakhriTok API', time=now())

@app.post('/api/auth/register')
def register():
    data = request.get_json(silent=True) or {}
    username = str(data.get('username', '')).strip().lstrip('@')
    email = str(data.get('email', '')).strip().lower()
    password = str(data.get('password', ''))
    if not re.fullmatch(r'[A-Za-z0-9_.]{3,24}', username):
        return jsonify(error='username_must_be_3_to_24_letters_numbers_dots_or_underscores'), 400
    if not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', email):
        return jsonify(error='valid_email_required'), 400
    if len(password) < 8:
        return jsonify(error='password_must_be_at_least_8_characters'), 400
    uid = str(uuid.uuid4())
    try:
        db().execute('INSERT INTO users(id,username,email,password_hash,created_at) VALUES(?,?,?,?,?)',
                     (uid, username, email, generate_password_hash(password), now()))
        db().commit()
    except sqlite3.IntegrityError:
        return jsonify(error='username_or_email_already_exists'), 409
    return jsonify(token=token_for(uid), user=user_public(db().execute('SELECT * FROM users WHERE id=?', (uid,)).fetchone())), 201

@app.post('/api/auth/login')
def login():
    data = request.get_json(silent=True) or {}
    identity = str(data.get('identity', data.get('email', data.get('username', '')))).strip().lower()
    password = str(data.get('password', ''))
    row = db().execute('SELECT * FROM users WHERE lower(email)=? OR lower(username)=?', (identity, identity)).fetchone()
    if row is None or not check_password_hash(row['password_hash'], password):
        return jsonify(error='incorrect_credentials'), 401
    return jsonify(token=token_for(row['id']), user=user_public(row))

@app.get('/api/me')
@auth_required
def me():
    return jsonify(user=user_public(g.user))

@app.patch('/api/me')
@auth_required
def update_me():
    data = request.get_json(silent=True) or {}
    bio = str(data.get('bio', g.user['bio']))[:160]
    username = str(data.get('username', g.user['username'])).strip().lstrip('@')
    if not re.fullmatch(r'[A-Za-z0-9_.]{3,24}', username): return jsonify(error='invalid_username'), 400
    try:
        db().execute('UPDATE users SET username=?, bio=? WHERE id=?', (username, bio, g.user['id'])); db().commit()
    except sqlite3.IntegrityError:
        return jsonify(error='username_already_exists'), 409
    return jsonify(user=user_public(db().execute('SELECT * FROM users WHERE id=?', (g.user['id'],)).fetchone()))

@app.get('/api/feed')
def feed():
    limit = min(max(request.args.get('limit', default=10, type=int), 1), 30)
    before = request.args.get('before')
    viewer_id = None
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        try: viewer_id = jwt.decode(auth[7:], SECRET, algorithms=['HS256'])['sub']
        except Exception: pass
    query = 'SELECT videos.* FROM videos WHERE videos.visibility="public"'
    params = []
    if viewer_id:
        query += ' AND ' + blocked_pair_sql(viewer_id); params.extend([viewer_id, viewer_id])
    if before: query += ' AND videos.created_at < ?'; params.append(before)
    query += ' ORDER BY videos.created_at DESC LIMIT ?'; params.append(limit)
    rows = db().execute(query, params).fetchall()
    return jsonify(items=[video_json(r, viewer_id) for r in rows], nextCursor=rows[-1]['created_at'] if len(rows) == limit else None)

@app.post('/api/videos')
@auth_required
def upload_video():
    file = request.files.get('video')
    if not file or not file.filename: return jsonify(error='video_file_required'), 400
    ext = Path(secure_filename(file.filename)).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS: return jsonify(error='unsupported_video_type'), 415
    caption = str(request.form.get('caption', '')).strip()[:2200]
    visibility = request.form.get('visibility', 'public')
    if visibility not in ('public', 'private'): visibility = 'public'
    filename = f'{uuid.uuid4().hex}{ext}'
    file.save(UPLOAD_DIR / filename)
    vid = str(uuid.uuid4())
    db().execute('INSERT INTO videos(id,user_id,caption,filename,created_at,visibility) VALUES(?,?,?,?,?,?)', (vid, g.user['id'], caption, filename, now(), visibility))
    db().commit()
    row = db().execute('SELECT * FROM videos WHERE id=?', (vid,)).fetchone()
    return jsonify(video=video_json(row, g.user['id'])), 201

@app.get('/uploads/<path:filename>')
def serve_upload(filename):
    # Production deployments should put uploads in object storage/CDN and enforce private-video access.
    return send_from_directory(UPLOAD_DIR, filename, conditional=True)

@app.get('/api/videos/<video_id>')
def get_video(video_id):
    row = db().execute('SELECT * FROM videos WHERE id=?', (video_id,)).fetchone()
    if row is None: return jsonify(error='video_not_found'), 404
    viewer = None
    header = request.headers.get('Authorization', '')
    if header.startswith('Bearer '):
        try: viewer = jwt.decode(header[7:], SECRET, algorithms=['HS256'])['sub']
        except Exception: pass
    if row['visibility'] == 'private' and viewer != row['user_id']: return jsonify(error='not_found'), 404
    db().execute('UPDATE videos SET views=views+1 WHERE id=?', (video_id,)); db().commit()
    row = db().execute('SELECT * FROM videos WHERE id=?', (video_id,)).fetchone()
    return jsonify(video=video_json(row, viewer))

@app.delete('/api/videos/<video_id>')
@auth_required
def delete_video(video_id):
    row = db().execute('SELECT * FROM videos WHERE id=?', (video_id,)).fetchone()
    if row is None: return jsonify(error='video_not_found'), 404
    if row['user_id'] != g.user['id']: return jsonify(error='forbidden'), 403
    try: (UPLOAD_DIR / row['filename']).unlink(missing_ok=True)
    except OSError: pass
    db().execute('DELETE FROM videos WHERE id=?', (video_id,)); db().commit()
    return jsonify(ok=True)

@app.post('/api/videos/<video_id>/like')
@auth_required
def toggle_like(video_id):
    conn = db()
    if not conn.execute('SELECT 1 FROM videos WHERE id=? AND visibility="public"', (video_id,)).fetchone(): return jsonify(error='video_not_found'), 404
    found = conn.execute('SELECT 1 FROM likes WHERE user_id=? AND video_id=?', (g.user['id'], video_id)).fetchone()
    if found: conn.execute('DELETE FROM likes WHERE user_id=? AND video_id=?', (g.user['id'], video_id)); liked = False
    else:
        conn.execute('INSERT INTO likes(user_id,video_id,created_at) VALUES(?,?,?)', (g.user['id'], video_id, now())); liked = True
        owner = conn.execute('SELECT user_id FROM videos WHERE id=?', (video_id,)).fetchone()['user_id']
        if owner != g.user['id']: conn.execute('INSERT INTO notifications(id,recipient_id,actor_id,kind,video_id,created_at) VALUES(?,?,?,?,?,?)', (str(uuid.uuid4()), owner, g.user['id'], 'like', video_id, now()))
    conn.commit()
    count = conn.execute('SELECT COUNT(*) n FROM likes WHERE video_id=?', (video_id,)).fetchone()['n']
    return jsonify(liked=liked, likes=count)

@app.get('/api/videos/<video_id>/comments')
def list_comments(video_id):
    rows = db().execute('SELECT comments.*,users.username FROM comments JOIN users ON users.id=comments.user_id WHERE video_id=? ORDER BY comments.created_at DESC LIMIT 100', (video_id,)).fetchall()
    return jsonify(items=[{'id':r['id'],'username':r['username'],'body':r['body'],'createdAt':r['created_at']} for r in rows])

@app.post('/api/videos/<video_id>/comments')
@auth_required
def add_comment(video_id):
    data = request.get_json(silent=True) or {}
    body = str(data.get('body', '')).strip()
    if not body or len(body) > 1000: return jsonify(error='comment_must_be_1_to_1000_characters'), 400
    video = db().execute('SELECT user_id FROM videos WHERE id=? AND visibility="public"', (video_id,)).fetchone()
    if not video: return jsonify(error='video_not_found'), 404
    cid = str(uuid.uuid4()); created = now()
    db().execute('INSERT INTO comments(id,user_id,video_id,body,created_at) VALUES(?,?,?,?,?)', (cid,g.user['id'],video_id,body,created))
    if video['user_id'] != g.user['id']:
        db().execute('INSERT INTO notifications(id,recipient_id,actor_id,kind,video_id,created_at) VALUES(?,?,?,?,?,?)', (str(uuid.uuid4()),video['user_id'],g.user['id'],'comment',video_id,created))
    db().commit()
    return jsonify(comment={'id':cid,'username':g.user['username'],'body':body,'createdAt':created}), 201

@app.post('/api/users/<user_id>/follow')
@auth_required
def toggle_follow(user_id):
    if user_id == g.user['id']: return jsonify(error='cannot_follow_self'), 400
    conn = db()
    if not conn.execute('SELECT 1 FROM users WHERE id=?', (user_id,)).fetchone(): return jsonify(error='user_not_found'), 404
    existing = conn.execute('SELECT 1 FROM follows WHERE follower_id=? AND followed_id=?', (g.user['id'],user_id)).fetchone()
    if existing: conn.execute('DELETE FROM follows WHERE follower_id=? AND followed_id=?', (g.user['id'],user_id)); following = False
    else:
        conn.execute('INSERT INTO follows(follower_id,followed_id,created_at) VALUES(?,?,?)', (g.user['id'],user_id,now())); following = True
        conn.execute('INSERT INTO notifications(id,recipient_id,actor_id,kind,created_at) VALUES(?,?,?,?,?)', (str(uuid.uuid4()),user_id,g.user['id'],'follow',now()))
    conn.commit()
    return jsonify(following=following,
      followers=conn.execute('SELECT COUNT(*) n FROM follows WHERE followed_id=?',(user_id,)).fetchone()['n'])

@app.get('/api/users/search')
def search_users():
    q = request.args.get('q','').strip().lstrip('@')[:50]
    if len(q) < 2: return jsonify(items=[])
    rows = db().execute('SELECT * FROM users WHERE username LIKE ? ORDER BY username LIMIT 30', (f'%{q}%',)).fetchall()
    return jsonify(items=[user_public(r) for r in rows])

@app.get('/api/users/<user_id>')
def profile(user_id):
    conn = db(); user = conn.execute('SELECT * FROM users WHERE id=?',(user_id,)).fetchone()
    if not user: return jsonify(error='user_not_found'),404
    counts = {'followers':conn.execute('SELECT COUNT(*) n FROM follows WHERE followed_id=?',(user_id,)).fetchone()['n'],
              'following':conn.execute('SELECT COUNT(*) n FROM follows WHERE follower_id=?',(user_id,)).fetchone()['n'],
              'videos':conn.execute('SELECT COUNT(*) n FROM videos WHERE user_id=? AND visibility="public"',(user_id,)).fetchone()['n']}
    videos = conn.execute('SELECT * FROM videos WHERE user_id=? AND visibility="public" ORDER BY created_at DESC LIMIT 30',(user_id,)).fetchall()
    return jsonify(user=user_public(user), counts=counts, videos=[video_json(r) for r in videos])

@app.post('/api/videos/<video_id>/save')
@auth_required
def toggle_save(video_id):
    conn=db()
    if not conn.execute('SELECT 1 FROM videos WHERE id=?',(video_id,)).fetchone(): return jsonify(error='video_not_found'),404
    row=conn.execute('SELECT 1 FROM saved_videos WHERE user_id=? AND video_id=?',(g.user['id'],video_id)).fetchone()
    if row: conn.execute('DELETE FROM saved_videos WHERE user_id=? AND video_id=?',(g.user['id'],video_id)); saved=False
    else: conn.execute('INSERT INTO saved_videos(user_id,video_id,created_at) VALUES(?,?,?)',(g.user['id'],video_id,now())); saved=True
    conn.commit(); return jsonify(saved=saved)

@app.get('/api/me/saved')
@auth_required
def saved_videos():
    rows=db().execute('SELECT videos.* FROM videos JOIN saved_videos ON saved_videos.video_id=videos.id WHERE saved_videos.user_id=? ORDER BY saved_videos.created_at DESC LIMIT 100',(g.user['id'],)).fetchall()
    return jsonify(items=[video_json(r,g.user['id']) for r in rows])

@app.get('/api/me/notifications')
@auth_required
def notifications():
    rows=db().execute('SELECT notifications.*,users.username FROM notifications JOIN users ON users.id=notifications.actor_id WHERE recipient_id=? ORDER BY created_at DESC LIMIT 100',(g.user['id'],)).fetchall()
    return jsonify(items=[{'id':r['id'],'actorUsername':r['username'],'kind':r['kind'],'videoId':r['video_id'],'createdAt':r['created_at'],'isRead':bool(r['is_read'])} for r in rows])

@app.post('/api/reports')
@auth_required
def report():
    data=request.get_json(silent=True) or {}
    reason=str(data.get('reason','')).strip()[:80]
    if not reason: return jsonify(error='reason_required'),400
    rid=str(uuid.uuid4())
    db().execute('INSERT INTO reports(id,reporter_id,video_id,reported_user_id,reason,details,created_at) VALUES(?,?,?,?,?,?,?)', (rid,g.user['id'],data.get('videoId'),data.get('userId'),reason,str(data.get('details',''))[:1000],now()))
    db().commit(); return jsonify(ok=True,reportId=rid),201

@app.post('/api/users/<user_id>/block')
@auth_required
def toggle_block(user_id):
    if user_id == g.user['id']: return jsonify(error='cannot_block_self'),400
    conn=db()
    if not conn.execute('SELECT 1 FROM users WHERE id=?',(user_id,)).fetchone(): return jsonify(error='user_not_found'),404
    row=conn.execute('SELECT 1 FROM blocks WHERE blocker_id=? AND blocked_id=?',(g.user['id'],user_id)).fetchone()
    if row: conn.execute('DELETE FROM blocks WHERE blocker_id=? AND blocked_id=?',(g.user['id'],user_id)); blocked=False
    else:
        conn.execute('INSERT INTO blocks(blocker_id,blocked_id,created_at) VALUES(?,?,?)',(g.user['id'],user_id,now()))
        conn.execute('DELETE FROM follows WHERE (follower_id=? AND followed_id=?) OR (follower_id=? AND followed_id=?)',(g.user['id'],user_id,user_id,g.user['id']))
        blocked=True
    conn.commit(); return jsonify(blocked=blocked)

@app.errorhandler(413)
def too_large(_e): return jsonify(error=f'file_too_large_max_{MAX_UPLOAD_MB}_MB'),413

@app.errorhandler(404)
def not_found(_e): return jsonify(error='route_not_found'),404

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8000'))
    init_db()
    app.run(host='0.0.0.0', port=port, debug=False)
