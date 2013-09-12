require 'sinatra'
require 'json'

set :port, 54329

use Rack::Auth::Basic, 'Restricted Area' do |_, password|
  password == 'supersecretshh'
end

get '/v2/catalog' do
  body = {
    'services' => [
      {
        'id' => 'custom-service-1',
        'name' => 'custom-service',
        'description' => 'A description of My Custom Service',
        'bindable' => true,
        'plans' => [
          {
            'id' => 'custom-plan-1',
            'name' => 'free',
            'description' => 'A description of the Free plan'
          }
        ]
      }
    ]
  }.to_json

  [200, {}, body]
end

post '/v2/service_instances' do
  json = JSON.parse(request.body.read)
  raise 'unexpected service_id' unless json['service_id'] == 'custom-service-1'
  raise 'unexpected plan_id' unless json['plan_id'] == 'custom-plan-1'

  body = {
    'id' => 'instance-id-1'
  }.to_json

  [200, {}, body]
end

post '/v2/service_bindings' do
  json = JSON.parse(request.body.read)
  raise 'unexpected service_instance_id' unless json['service_instance_id'] == 'instance-id-1'

  body = {
    'id' => 'binding-id-1'
  }.to_json

  [200, {}, body]
end
