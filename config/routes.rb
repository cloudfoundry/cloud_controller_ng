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
  get '/v3/apps/:guid/stats', to: 'apps_v3#stats'

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
  get '/apps/:guid/stats', to: 'apps_v3#stats'

  # processes
  get '/processes', to: 'processes#index'
  get '/processes/:guid', to: 'processes#show'
  patch '/processes/:guid', to: 'processes#update'
  delete '/processes/:guid/instances/:index', to: 'processes#terminate'
  put '/processes/:guid/scale', to: 'processes#scale'
  get '/processes/:guid/stats', to: 'processes#stats'

  get '/v3/processes', to: 'processes#index'
  get '/v3/processes/:guid', to: 'processes#show'
  patch '/v3/processes/:guid', to: 'processes#update'
  delete '/v3/processes/:guid/instances/:index', to: 'processes#terminate'
  put '/v3/processes/:guid/scale', to: 'processes#scale'
  get '/v3/processes/:guid/stats', to: 'processes#stats'

  # packages
  get '/v3/packages', to: 'packages#index'
  get '/v3/packages/:guid', to: 'packages#show'
  post '/v3/packages/:guid/upload', to: 'packages#upload'
  get '/v3/packages/:guid/download', to: 'packages#download'
  delete '/v3/packages/:guid', to: 'packages#destroy'
  get '/v3/apps/:app_guid/packages', to: 'packages#index'
  post '/v3/apps/:app_guid/packages', to: 'packages#create'

  get '/packages', to: 'packages#index'
  get '/packages/:guid', to: 'packages#show'
  post '/packages/:guid/upload', to: 'packages#upload'
  get '/packages/:guid/download', to: 'packages#download'
  delete '/packages/:guid', to: 'packages#destroy'
  get '/apps/:app_guid/packages', to: 'packages#index'
  post '/apps/:app_guid/packages', to: 'packages#create'

  # droplets
  post '/v3/packages/:package_guid/droplets', to: 'droplets#create'
  get '/v3/droplets', to: 'droplets#index'
  get '/v3/droplets/:guid', to: 'droplets#show'
  delete '/v3/droplets/:guid', to: 'droplets#destroy'
  get '/v3/apps/:app_guid/droplets', to: 'droplets#index'

  post '/packages/:package_guid/droplets', to: 'droplets#create'
  get '/droplets', to: 'droplets#index'
  get '/droplets/:guid', to: 'droplets#show'
  delete '/droplets/:guid', to: 'droplets#destroy'
  get '/apps/:app_guid/droplets', to: 'droplets#index'

  # route_mappings
  post '/apps/:app_guid/route_mappings', to: 'route_mappings#create'
  get '/apps/:app_guid/route_mappings/:route_mapping_guid', to: 'route_mappings#show'
  get '/apps/:app_guid/route_mappings', to: 'route_mappings#index'
  delete 'apps/:app_guid/route_mappings/:route_mapping_guid', to: 'route_mappings#destroy'

  # apps_processes
  get '/v3/apps/:guid/processes', to: 'apps_processes#index'
  get '/v3/apps/:guid/processes/:type', to: 'apps_processes#show'
  put '/v3/apps/:guid/processes/:type/scale', to: 'apps_processes#scale'
  delete '/v3/apps/:guid/processes/:type/instances/:index', to: 'apps_processes#terminate'
  get '/v3/apps/:guid/processes/:type/stats', to: 'apps_processes#stats'

  get '/apps/:guid/processes', to: 'apps_processes#index'
  get '/apps/:guid/processes/:type', to: 'apps_processes#show'
  put '/apps/:guid/processes/:type/scale', to: 'apps_processes#scale'
  delete '/apps/:guid/processes/:type/instances/:index', to: 'apps_processes#terminate'
  get '/apps/:guid/processes/:type/stats', to: 'apps_processes#stats'

  # tasks
  get '/tasks', to: 'tasks#index'
  get '/tasks/:task_guid', to: 'tasks#show'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel'

  post '/apps/:app_guid/tasks', to: 'tasks#create'
  get '/apps/:app_guid/tasks', to: 'tasks#index'
  get '/apps/:app_guid/tasks/:task_guid', to: 'tasks#show'
  put '/apps/:app_guid/tasks/:task_guid/cancel', to: 'tasks#cancel'

  # service_bindings
  post '/service_bindings', to: 'service_bindings#create'
  get '/service_bindings/:guid', to: 'service_bindings#show'
  get '/service_bindings', to: 'service_bindings#index'
  delete '/service_bindings/:guid', to: 'service_bindings#destroy'

  # errors
  match '404', to: 'errors#not_found', via: :all
  match '500', to: 'errors#internal_error', via: :all
  match '400', to: 'errors#bad_request', via: :all
end
