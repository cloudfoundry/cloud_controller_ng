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

put '/v2/service_instances/:service_instance_id' do
  json = JSON.parse(request.body.read)
  raise 'unexpected plan_id' unless json['plan_id'] == 'custom-plan-1'

  body = {
    'dashboard_url' => 'http://dashboard'
  }.to_json
  [201, {}, body]
end

put '/v2/service_bindings/:service_binding_id' do
  json = JSON.parse(request.body.read)
  raise 'missing service_instance_id' unless json['service_instance_id']

  body = {
    'credentials' => {
      'username' => 'admin',
      'password' => 'secret'
    }
  }.to_json

  [200, {}, body]
end

delete '/v2/service_bindings/:service_binding_id' do
  [204, {}, '']
end
