require 'sinatra'
require 'json'

set :port, 54329

use Rack::Auth::Basic, 'Restricted Area' do |_, password|
  password == 'supersecretshh'
end

@@instance_count = 0
@@binding_count = 0

@@plans = [
  {
    'id' => 'custom-plan-1',
    'name' => 'free',
    'description' => 'A description of the Free plan'
  },
  {
    'id' => 'custom-plan-2',
    'name' => 'also free',
    'description' => 'Two for twice the price!'
  }
]

get '/v2/catalog' do
  body = {
    'services' => [
      {
        'id' => 'custom-service-1',
        'name' => 'custom-service',
        'description' => 'A description of My Custom Service',
        'bindable' => true,
        'tags' => ['mysql', 'relational'],
        'plans' => @@plans
      }
    ]
  }.to_json

  [200, {}, body]
end

put '/v2/service_instances/:service_instance_id' do
  json = JSON.parse(request.body.read)
  raise 'unexpected plan_id' unless json['plan_id'] == 'custom-plan-1'

  @@instance_count += 1

  body = {
    'dashboard_url' => 'http://dashboard'
  }.to_json
  [201, {}, body]
end

put '/v2/service_instances/:service_instance_id/service_bindings/:service_binding_id' do
  json = JSON.parse(request.body.read)

  @@binding_count += 1

  body = {
    'credentials' => {
      'username' => 'admin',
      'password' => 'secret'
    }
  }.to_json

  [200, {}, body]
end

delete '/v2/service_instances/:service_instance_id/service_bindings/:service_binding_id' do
  @@binding_count -= 1

  [204, {}, '']
end

delete '/v2/service_instances/:service_instance_id' do
  @@instance_count -= 1

  [204, {}, '']
end

get '/counts' do
  body = {
    instances: @@instance_count,
    bindings: @@binding_count
  }.to_json

  [200, {}, body]
end

delete '/plan/last' do
  @@plans.pop
  [204, {}, nil]
end
