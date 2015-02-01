from urlparse import urlparse
from google.appengine.api import users
from google.appengine.ext import ndb
import os
import webapp2

class WhiteListEntry(ndb.Model):
    emailAddress = ndb.StringProperty()

class MainHandler(webapp2.RequestHandler):
    def get(self):

        # Put in a minimal, temporary auth protection.

        # Everyone has to be logged in via the YAML.
        user = users.get_current_user()
        email = user.email().lower()

        # Assume Auth failure.
        authenticated = False

        # All Google is whitelisted.
        if email.endswith("@google.com"):
            authenticated = True

        # For local testing.
        if isDevelopment():
            authenticated = True

        res = WhiteListEntry.query(WhiteListEntry.emailAddress == email).get()
        if res is not None:
            if res.emailAddress == email:
                authenticated = True

        if not authenticated:
            self.response.status = 401
            return
        else:
            parsedURL = urlparse(self.request.uri)
            path = parsedURL.path;
            targetSplits = path.split('/')

            # If it is a request for a file in the TLD, serve as is.
            if targetSplits[1].find('.') > 0:
                newPath = "/".join(targetSplits[1:])
                if newPath == '':
                    _serve(self.response, 'dartpad.html')
                else:
                    _serve(self.response, newPath)
                return

            # If it is a request for a TLD psuedo-item, serve back the main page
            if len(targetSplits) < 3:
                _serve(self.response, 'dartpad.html')
                return


            # If it is a request for something in the packages folder, serve it
            if targetSplits[1] == 'packages':
                newPath = "/".join(targetSplits[1:])
                if newPath == '':
                    _serve(self.response, 'dartpad.html')
                else:
                    _serve(self.response, newPath)
                return

            # Otherwise it's a request for a item after the gist psudeo path
            # drop the gist and serve it.
            if len(targetSplits) >= 3:
                newPath = "/".join(targetSplits[2:])
                if newPath == '':
                    _serve(self.response, 'dartpad.html')
                else:
                    _serve(self.response, newPath)
                return


# Return whether we're running in the development server or not.
def isDevelopment():
    return os.environ['SERVER_SOFTWARE'].startswith('Development')


# Serve the files.
def _serve(resp, path):

    if not os.path.isfile(path):
        resp.status = 404
        resp.write("<html><h1>404: Not found</h1></html>")
        return

    if path.endswith('.css'):
        resp.content_type = 'text/css'

    if path.endswith('.js'):
        resp.content_type = 'application/javascript'


    f = open(path, 'r')
    c = f.read()
    resp.write(c)
    return


app = webapp2.WSGIApplication([
    ('.*', MainHandler)
], debug=False)
