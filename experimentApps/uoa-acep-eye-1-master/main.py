#!/usr/bin/env python
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
import jinja2
import webapp2
import logging
import re
import threading
import csv

from google.appengine.ext import ndb
from google.appengine.api import users


def include_file(name):
    return jinja2.Markup(loader.get_source(JINJA_ENVIRONMENT, name)[0])


loader = jinja2.FileSystemLoader(os.path.dirname(__file__))
JINJA_ENVIRONMENT = jinja2.Environment(
    loader=loader,
    extensions=['jinja2.ext.autoescape'])

JINJA_ENVIRONMENT.globals['include_file'] = include_file

# The following constant is used to distinguish rows in the
# database for this particular experiment (and version) from
# other experimental data that may be in the same database.
ENTITY_KIND = "kr-uoa-acep-eye-1.0"


#
# This class represents an Entity (row) in the Google App Engine
# database.
#
class UserData(ndb.Expando):
    date = ndb.DateTimeProperty(auto_now_add=True, indexed=False)

    @classmethod
    def _get_kind(cls):
        return ENTITY_KIND


#
# This class is used to serve the HTTP request to launch the
# given experiment. It is responsible for creating an
# appropriate database entry, recording various parameters
# and headers of interest, detecting whether a Mechanical Turk
# user has previously executed the experiment, and serving up
# either the main experiment page or the relevant notice of
# exclusion.
#
class MainPage(webapp2.RequestHandler):
    runIndex = 0

    runIndexLock = threading.Lock()

    def get(self, page_template="index.html"):
        # increment the runIndex which is passed in to
        # the HTML page template, for use by those experiments
        # that may wish to allocate people to conditions
        # on a round robin basis.
        with MainPage.runIndexLock:
            index = MainPage.runIndex
            MainPage.runIndex += 1

        # Keep various generic request parameters of interest
        cond = self.request.get("cond")
        src = self.request.get("src")
        batch = self.request.get("batch")
        config = self.request.get("config")

        mt_worker_id = self.request.get("mtWorkerId")
        mt_hit_id = self.request.get("mtHitId")
        mt_assignment_id = self.request.get("mtAssignmentId")

        # Create a new database entity (row)
        entity = UserData()

        # Record the request parameters of interest and copy
        # all the HTTP Request header fields into the entity
        # allowing dropout analysis based on browser type etc.

        # First, record the request properties of interest
        setattr(entity, "cond", cond)
        setattr(entity, "src", src)
        setattr(entity, "batch", batch)
        setattr(entity, "config", config)
        setattr(entity, "mtWorkerId", mt_worker_id)
        setattr(entity, "mtHitId", mt_hit_id)
        setattr(entity, "mtAssignmentId", mt_assignment_id)

        # Next, the request headers
        content = dict(self.request.headers)

        for k, v in content.iteritems():
            setattr(entity, k, v)

        # If a Mechanical Turk Worker Id has been supplied
        # we will check whether we have seen it before.
        if mt_worker_id:
            is_repeat = check_repeats(mt_worker_id)
            setattr(entity, "mtWorkerRepeat", is_repeat)
        else:
            is_repeat = False

        # save the entity in the database
        key = entity.put()

        logging.info('page_template: ' + page_template);
        logging.info('run index: ' + str(index) + ' created user: ' + str(key) + ' cond: ' + cond)

        # Now decide whether to run the real experiment or not.

        if is_repeat:
            # Show the notice of exclusion
            template = JINJA_ENVIRONMENT.get_template('repeat.html')
        else:
            # Launch the experiment
            template = JINJA_ENVIRONMENT.get_template(page_template)

        self.response.write(template.render(uid=str(key.id()),
                                            runIndex=index,
                                            cond=cond,
                                            src=src,
                                            batch=batch,
                                            config=config,
                                            mtWorkderId=mt_worker_id,
                                            mtHitId=mt_hit_id,
                                            mtAssignmentId=mt_assignment_id))


#
# This class is used to serve the admin pages.
#
class AdminPage(webapp2.RequestHandler):
    def get(self, page_template="admin.html"):
        logging.info('page_template: ' + page_template);

        # Load the admin page
        template = JINJA_ENVIRONMENT.get_template(page_template)
        self.response.write(template.render())


#
# The class is responsible for serving the "finish" page that
# displays the confirmation code when the experiment has been
# successfully completed.
#
class FinishPage(webapp2.RequestHandler):

    def get(self):
        uid = self.request.get("uid")
        logging.info('user finished: ' + uid)
        template = JINJA_ENVIRONMENT.get_template('finish.html')
        self.response.write(template.render(code='fm-1-0-' + uid))


#
# This request (when enabled) will return a CSV file
# containing all result rows for the given experiment.
# To disable this functionality, simply comment out the
# appropriate line in the Web Application configuration
# at the bottom of this file.
#
class LoadResults(webapp2.RequestHandler):

    def process(self):
        self.response.headers['Content-Type'] = 'text/csv'
        self.response.headers['Content-Disposition'] = 'inline;filename=results.csv'

        property_names = set()
        data = UserData.query().fetch()

        for u in data:
            logging.info("found uid: " + str(u.key.id()))
            property_names.update(u._properties.keys())

        writer = csv.DictWriter(self.response.out, fieldnames=sorted(property_names))
        writer.writeheader()

        for u in data:
            d = dict()

            try:
                for k, v in u._properties.iteritems():
                    d[k] = str(v._get_user_value(u))

                writer.writerow(d)

            except UnicodeEncodeError:
                logging.error("UnicodeEncodeError detected, row ignored");

    def post(self):
        self.process()

    def get(self):
        self.process()


#
# The following class may be used to save the http headers
# present in a given request. This class is essentially
# deprecated, since headers are saved along with the initial
# request to launch the experiment.
#
class SaveHeaders(webapp2.RequestHandler):

    def process(self):
        uid = self.request.get("uid")
        logging.info("saving headers for uid: " + str(uid))
        key = ndb.Key(ENTITY_KIND, long(uid))
        entity = key.get();
        logging.info(str(entity))

        content = dict(self.request.headers)

        for k, v in content.iteritems():
            setattr(entity, k, v)

        entity.put()
        self.response.headers['Content-Type'] = 'text/plain'
        self.response.out.write('Storing browser header data for:')
        self.response.out.write(key.id())

    def post(self):
        self.process()

    def get(self):
        self.process()


#
# The following class is used to save the results of
# an experiment. Essentially it extracts each of the request
# parameters from the GET/POST request and saves
# the name value pairs in the Google App Engine database.
#
class SaveResults(webapp2.RequestHandler):
    def process(self):
        uid = self.request.get("uid")
        logging.info("saving headers for uid: " + str(uid))
        key = ndb.Key(ENTITY_KIND, long(uid))
        entity = key.get();
        logging.info(str(entity))

        content = dict(self.request.params)

        for k, v in content.iteritems():
            setattr(entity, k, v)

        entity.put()

        self.response.headers['Content-Type'] = 'text/plain'
        self.response.out.write('Saving results for:')
        self.response.out.write(entity.uid)

    def post(self):
        self.process()

    def get(self):
        self.process()


# The following function scans all the files found in the
# "excluded_workers" directory and returns a boolean value to
# indicate whether or not the given Mechanical Turk Worker Id
# is found in any of the files contained therein.
#
# Note that the search is s simple regular expression search,
# and asu such, it may be possible for the function to return
# a false positive under certain circumstances. However, if
# the directory contains simply files of the form:
#  Batch_<batch number>_batch_results.csv
# as intended, then it is highly unlikely that a false positive
# will occur.
#
def check_repeats(worker_id):
    for current_file in os.listdir("excluded_workers"):
        with open("excluded_workers/" + current_file) as origin_file:
            for line in origin_file:
                match = re.findall(r'' + worker_id, line)
                if match:
                    return True

    return False

#
# Define the simple Web Application for this experiment
#
application = webapp2.WSGIApplication([
    ('/', MainPage),
    ('/main', MainPage),
    ('/admin', AdminPage),
    ('/finish.html', FinishPage),
# Uncomment the following line to enable download of results    
    ('/info', LoadResults),
    ('/saveHeaders', SaveHeaders),
    ('/saveResults', SaveResults)
], debug=True)
