#!/usr/bin/env bash

set -ex

bundle exec rake db:migrate
bundle exec rake db:seed

exit 0

