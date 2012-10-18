Bonnie
------

Bonnie is a tool for the generation of quality measures.

Environment
-----------

This project currently uses Ruby 1.9.3 and is built using [Bundler](http://gembundler.com/). To get all of the
dependencies for the project, first install bundler:

    gem install bundler

Then run bundler to grab all of the necessary gems:

    bundle install

The Patient Data Server relies on a MongoDB [MongoDB](http://www.mongodb.org/) running a minimum of version 2.2.0 or
higher. To get and install MongoDB refer to:

    http://www.mongodb.org/display/DOCS/Quickstart

Getting Started
---------------

Run the Bonnie server by running:

    bundle exec rails server

Navigate to http://localhost:3000. You should see a login page. Click the "Create new account" link and create an account. Take note of the username you use when creating the account.

Obtain clinical quality measures in HQMF format (TODO: put in the location to go to for the measures). Next, import the quality measures with the following command:

    bundle exec rake measures:load_all[PATH_TO_MEASURES,username,true]

Bonnie attempts to find relations between code sets in different quality measures so that it can select common codes when generating patients. To enable this process run this command:

    bundle exec rake concepts:load_all

Bonnie also uses a white list of codes to choose from when generating patients. (TODO: provide location of a white list) To load that list, run:

    bundle exec rake value_sets:load_white_list[PATH_TO_WHITELIST]

Lastly, finalize the measures for execution by running:

    bundle exec rake measures:export_all

License
-------

The Bonnie source code is licensed under Apache 2.0.

All Clinical Quality Measure defintions available in this repository are from

http://www.qualityforum.org/Projects/e-g/eMeasures/Electronic_Quality_Measures.aspx

These measure defintions are not covered by the Apache 2.0 license.  Please contact NQF (www.qualityforum.org) or the specific measure stewards with questions specific to the measure defintions or licensing.
