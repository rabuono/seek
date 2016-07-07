#!/bin/bash

# Change secret token
sed -i "s/secret_token = '.*'/key = '"`bundle exec rake secret`"'/" config/initializers/secret_token.rb

# DB config

# cp docker/database.docker.mysql.yml config/database.yml

# bundle exec rake db:setup


# Soffice service
soffice --headless --accept="socket,host=127.0.0.1,port=8100;urp;" --nofirststartwizard > /dev/null 2>&1 &

# Workers
bundle exec rake seek:workers:start

# Search
bundle exec rake sunspot:solr:start

bundle exec rails server -b 0.0.0.0 &

nginx -g 'daemon off;'
