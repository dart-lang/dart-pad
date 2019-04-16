from urlparse import urlparse
from google.appengine.ext import ndb
import os
import webapp2
import logging

class WhiteListEntry(ndb.Model):
    emailAddress = ndb.StringProperty()


class MainHandler(webapp2.RequestHandler):

    def options(self):
        '''options is required for CORS'''
        self.response.headers['Access-Control-Allow-Origin'] = '*'
        self.response.headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
        self.response.headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE'

    def get(self):
        mainPage = 'index.html'

        if self.request.uri.find("try.dartlang.org") > 0:
            self.redirect("https://dartpad.dartlang.org")

        parsedURL = urlparse(self.request.uri)
        path = parsedURL.path
        targetSplits = path.split('/')

        if os.path.isfile(path):
            _serve(self.response, path)
            return

        # If it is a request for a file in the TLD, serve as is.
        if targetSplits[1].find('.') > 0:
            newPath = "/".join(targetSplits[1:])
            if newPath == '':
                _serve(self.response, mainPage)
            else:
                _serve(self.response, newPath)
            return

        # If it is a request for a TLD psuedo-item, serve back the main page
        if len(targetSplits) < 3:
            _serve(self.response, mainPage)
            return

        # If it is a request for something in the packages folder, serve it
        if targetSplits[1] == 'packages':
            newPath = "/".join(targetSplits[1:])
            if newPath == '':
                _serve(self.response, mainPage)
            else:
                _serve(self.response, newPath)
            return

        # If it is a request for something in the experimental folder, serve it
        if targetSplits[1] == 'experimental':
            newPath = "/".join(targetSplits[1:])
            if newPath == '':
                _serve(self.response, mainPage)
            else:
                _serve(self.response, newPath)
            return

        # If it is a request for something in the scripts/assets folder, serve it
        if targetSplits[1] == 'scripts' and targetSplits[2] == 'assets':
            newPath = "/".join(targetSplits[1:])
            _serve(self.response, newPath)
            return

        # Otherwise it's a request for a item after the gist pseudo path
        # drop the gist and serve it.
        if len(targetSplits) >= 3:
            newPath = "/".join(targetSplits[2:])
            if newPath == '':
                _serve(self.response, mainPage)
            else:
                _serve(self.response, newPath)
            return


# Return whether we're running in the development server or not.
def isDevelopment():
    return os.environ['SERVER_SOFTWARE'].startswith('Development')


# Serve the files.
def _serve(resp, path):
    logging.info('Serving {0}'.format(path))

    if not os.path.isfile(path):
        resp.status = 404
        resp.write("<html><h1>404: Not found</h1></html>")
        return

    if path.endswith('.css'):
        resp.content_type = 'text/css'
    if path.endswith('.svg'):
        resp.content_type = 'image/svg+xml'
    if path.endswith('.js'):
        resp.content_type = 'application/javascript'
    if path.endswith('.ico'):
        resp.content_type = 'image/x-icon'
    if path.endswith('.html'):
        resp.content_type = 'text/html'
    if path.endswith('.png'):
        resp.content_type = 'image/png'
    if path.endswith('.json'):
        resp.content_type = 'application/json'
        resp.headers.add_header('Access-Control-Allow-Origin', '*')

    logging.info('Headers {0}'.format(resp.headers))

    f = open(path, 'r')
    c = f.read()
    resp.write(c)
    return


app = webapp2.WSGIApplication([
    ('.*', MainHandler)
], debug=False)
