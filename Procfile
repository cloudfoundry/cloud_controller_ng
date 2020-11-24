web:                bin/cloud_controller -c /config/cloud_controller_ng.yml -s /config/secrets.yml
local-worker:       bundle exec rake jobs:local
api-worker:         bundle exec rake jobs:generic
clock:              bundle exec rake clock:start
deployment-updater: bundle exec rake deployment_updater:start
migrate:            /bin/bash -c 'bundle exec rake db:connect && bundle exec rake db:setup_database && bundle exec rake db:terminate_istio_if_exists'

