require 'sinatra'

set :port, 54329

use Rack::Auth::Basic, 'Restricted Area' do |_, password|
  password == 'supersecretshh'
end

get '/v3' do
  [200, {}, '["OK"]']
end
