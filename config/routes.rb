Rails.application.routes.draw do
  # apps
  get '/v3/apps', to: 'apps_v3#index'
  post '/v3/apps', to: 'apps_v3#create'
  get '/v3/apps/:guid', to: 'apps_v3#show'
  put '/v3/apps/:guid', to: 'apps_v3#update'
  patch '/v3/apps/:guid', to: 'apps_v3#update'
  delete '/v3/apps/:guid', to: 'apps_v3#destroy'
  put '/v3/apps/:guid/start', to: 'apps_v3#start'
  put '/v3/apps/:guid/stop', to: 'apps_v3#stop'
  get '/v3/apps/:guid/env', to: 'apps_v3#show_environment'
  put '/v3/apps/:guid/current_droplet', to: 'apps_v3#assign_current_droplet'

  get '/apps', to: 'apps_v3#index'
  post '/apps', to: 'apps_v3#create'
  get '/apps/:guid', to: 'apps_v3#show'
  put '/apps/:guid', to: 'apps_v3#update'
  patch '/apps/:guid', to: 'apps_v3#update'
  delete '/apps/:guid', to: 'apps_v3#destroy'
  put '/apps/:guid/start', to: 'apps_v3#start'
  put '/apps/:guid/stop', to: 'apps_v3#stop'
  get '/apps/:guid/env', to: 'apps_v3#show_environment'
  put '/apps/:guid/current_droplet', to: 'apps_v3#assign_current_droplet'

  # processes
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

  # packages
  get '/v3/packages', to: 'packages#index'
  get '/v3/packages/:guid', to: 'packages#show'
  post '/v3/packages/:guid/upload', to: 'packages#upload'
  get '/v3/packages/:guid/download', to: 'packages#download'
  delete '/v3/packages/:guid', to: 'packages#destroy'
  post '/v3/packages/:guid/droplets', to: 'packages#stage'

  get '/packages', to: 'packages#index'
  get '/packages/:guid', to: 'packages#show'
  post '/packages/:guid/upload', to: 'packages#upload'
  get '/packages/:guid/download', to: 'packages#download'
  delete '/packages/:guid', to: 'packages#destroy'
  post '/packages/:guid/droplets', to: 'packages#stage'

  # droplets
  get '/v3/droplets', to: 'droplets#index'
  get '/v3/droplets/:guid', to: 'droplets#show'
  delete '/v3/droplets/:guid', to: 'droplets#destroy'

  get '/droplets', to: 'droplets#index'
  get '/droplets/:guid', to: 'droplets#show'
  delete '/droplets/:guid', to: 'droplets#destroy'

  # apps_routes
  get '/v3/apps/:guid/routes', to: 'apps_routes#index'
  delete '/v3/apps/:guid/routes', to: 'apps_routes#destroy'
  put '/v3/apps/:guid/routes', to: 'apps_routes#add_route'

  get '/apps/:guid/routes', to: 'apps_routes#index'
  delete '/apps/:guid/routes', to: 'apps_routes#destroy'
  put '/apps/:guid/routes', to: 'apps_routes#add_route'

  # apps_processes
  get '/v3/apps/:guid/processes', to: 'apps_processes#index'
  get '/v3/apps/:guid/processes/:type', to: 'apps_processes#show'
  put '/v3/apps/:guid/processes/:type/scale', to: 'apps_processes#scale'
  delete '/v3/apps/:guid/processes/:type/instances/:index', to: 'apps_processes#terminate'

  get '/apps/:guid/processes', to: 'apps_processes#index'
  get '/apps/:guid/processes/:type', to: 'apps_processes#show'
  put '/apps/:guid/processes/:type/scale', to: 'apps_processes#scale'
  delete '/apps/:guid/processes/:type/instances/:index', to: 'apps_processes#terminate'

  # apps_packages
  get '/v3/apps/:guid/packages', to: 'apps_packages#index'
  post '/v3/apps/:guid/packages', to: 'apps_packages#create'

  get '/apps/:guid/packages', to: 'apps_packages#index'
  post '/apps/:guid/packages', to: 'apps_packages#create'

  # apps_droplets
  get '/v3/apps/:guid/droplets', to: 'apps_droplets#index'

  get '/apps/:guid/droplets', to: 'apps_droplets#index'

  match '404', to: 'errors#not_found', via: :all
  match '500', to: 'errors#internal_error', via: :all
  match '400', to: 'errors#bad_request', via: :all
end
