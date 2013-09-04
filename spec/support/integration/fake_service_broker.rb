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
  raise "unexpected service_id" unless json['service_id'] == 'custom-service-1'
  raise "unexpected plan_id" unless json['plan_id'] == 'custom-plan-1'

  if json['reference_id'] == 'already-exists'
    #TODO
  else
    body = {
      'id' => 'actual-id-1'
    }.to_json

    [200, {}, body]
  end
end

#DELETE /v2/service_instances/:id
