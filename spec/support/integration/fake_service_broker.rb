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
