from flask import Flask, send_file
import os
import string

# `entrypoint` is not defined in app.yaml, so App Engine will look for an app
# called `app` in this file.
app = Flask(__name__)

if __name__ == '__main__':
    # This is used when running locally only.
    app.run(host='127.0.0.1', port=8080, debug=True)

# Files that the server is allowed to serve. Additional static files are
# served via directives in app.yaml.
VALID_FILES= [
    'dark_mode.js',
    'dart-192.png',
    'embed-dart.html',
    'embed-flutter.html',
    'embed-html.html',
    'embed-inline.html',
    'embed-.html',
    'fav_icon.ico',
    'index.html',
    'inject_embed.dart.js',
    'robots.txt'
]

# File extensions and the mimetypes with which they should be served.
DEFAULT_CONTENT_TYPE = 'application/octet-stream'

CONTENT_TYPES = {
    '.css': 'text/css',
    '.html': 'text/html',
    '.ico': 'image/x-icon',
    '.js': 'application/javascript',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.txt': 'text/plain',
}

# Routes.

@app.route('/')
def index():
    return _serve_file('index.html')

@app.route('/<item_name>')
def item(item_name):
    print(item_name)

    if item_name in VALID_FILES:
        return _serve_file(item_name)

    if len(item_name) == 32 and all(c in string.hexdigits for c in item_name):
        return _serve_file('index.html')

    return _serve_404()

# Helpers.

def _serve_file(file_path):
    if not os.path.isfile(file_path):
        return _serve_404()
    file_name, file_ext = os.path.splitext(file_path)
    mimetype = CONTENT_TYPES.get(file_ext, DEFAULT_CONTENT_TYPE)
    return send_file(file_path, mimetype=mimetype)

def _serve_404():
    return '<html><h1>404: Not found</h1></html>', 404
