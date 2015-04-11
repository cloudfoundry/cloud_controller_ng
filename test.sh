RET=0
until [ $RET != 0 ]; do
  bundle exec rspec spec/api/documentation/v3/apps_api_spec.rb
  RET=$?
done
