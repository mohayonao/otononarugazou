#!/usr/bin/env python
# -*- coding: utf-8 -*-

#
# Copyright 2007 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os
import webapp2

from google.appengine.api import memcache
from google.appengine.ext import blobstore
from google.appengine.ext import db
from google.appengine.ext.webapp import blobstore_handlers

class GazouKeyList(db.Model):
    data = db.StringListProperty()

class UploadHandler(blobstore_handlers.BlobstoreUploadHandler):
    def post(self):
        files = self.get_uploads('file')
        if len(files) != 1:
            return self.error(404)
        blob_info = files[0]
        if blob_info.content_type != 'image/png':
            blob_info.delete()
            return self.error(404)
        key = str(files[0].key())
        glist = GazouKeyList.get_or_insert('recent')
        glist.data.insert(0, key)
        glist.data = glist.data[:12]
        glist.save()
        
        memcache.set('recent', glist.data)
        
        self.response.out.write(key)
        
class ServeHandler(blobstore_handlers.BlobstoreDownloadHandler):        
    def get(self, gazou_id):
        if not blobstore.get(gazou_id):
            self.error(404)
        else:
            self.response.headers['Cache-Control'] = 'private, max-age=604800'
            self.send_blob(gazou_id)
        
class ListHandler(webapp2.RequestHandler):
    def get(self):
        glist = memcache.get('recent')
        if glist is None:
            glist = GazouKeyList.get_or_insert('recent').data
            memcache.set('recent', glist)
        self.response.headers['Content-Type'] = 'application/json'
        self.response.out.write('[' + ','.join(map(lambda s:'"'+s+'"', glist)) + ']')
        
class GetUploadURLHandler(webapp2.RequestHandler):
    def get(self):
        self.response.out.write(blobstore.create_upload_url('/upload'))

class RemoveHandler(webapp2.RequestHandler):
    def get(self, gazou_id):
        blobstore.delete(gazou_id)

        glist = GazouKeyList.get_or_insert('recent')
        if gazou_id in glist.data:
            glist.data.remove(gazou_id)
            glist.save()
            memcache.set('recent', glist.data)
        self.redirect('/')
        
app = webapp2.WSGIApplication([
        ('^/upload$'        , UploadHandler      ),
        ('^/(.+)\.png$'     , ServeHandler       ),
        ('^/list$'          , ListHandler        ),
        ('^/get_upload_url$', GetUploadURLHandler),
        ('^/rm/(.+)$'       , RemoveHandler      ),
        ], debug=True)
