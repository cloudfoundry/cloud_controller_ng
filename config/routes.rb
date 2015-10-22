Rails.application.routes.draw do
  get '/processes', to: 'processes#index'
  get '/processes/:guid', to: 'processes#show'
  patch '/processes/:guid', to: 'processes#update'
  delete '/processes/:guid/instances/:index', to: 'processes#terminate'
  put '/processes/:guid/scale', to: 'processes#scale'

  get '/v3/processes', to: 'processes#index'
  get '/v3/processes/:guid', to: 'processes#show'
  patch '/v3/processes/:guid', to: 'processes#update'
  delete '/v3/processes/:guid/instances/:index', to: 'processes#terminate'
  put '/v3/processes/:guid/scale', to: 'processes#scale'

  get '/v3/packages', to: 'packages#index'
  get '/v3/packages/:guid', to: 'packages#show'
  post '/v3/packages/:guid/upload', to: 'packages#upload'
  get '/v3/packages/:guid/download', to: 'packages#download'
  delete '/v3/packages/:guid', to: 'packages#destroy'
  post '/v3/packages/:guid/droplets', to: 'packages#stage'

  get '/v3/droplets', to: 'droplets#index'
  get '/v3/droplets/:guid', to: 'droplets#show'
  delete '/v3/droplets/:guid', to: 'droplets#destroy'

  get '/v3/apps/:guid/routes', to: 'apps_routes#index'
  delete '/v3/apps/:guid/routes', to: 'apps_routes#destroy'
  put '/v3/apps/:guid/routes', to: 'apps_routes#add_route'

  match '404', :to => 'errors#not_found', via: :all
  match '500', :to => 'errors#internal_error', via: :all
  match '400', :to => 'errors#bad_request', via: :all
end
