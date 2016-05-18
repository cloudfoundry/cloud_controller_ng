Rails.application.routes.draw do
  # apps
  get '/apps', to: 'apps_v3#index'
  post '/apps', to: 'apps_v3#create'
  get '/apps/:guid', to: 'apps_v3#show'
  put '/apps/:guid', to: 'apps_v3#update'
  patch '/apps/:guid', to: 'apps_v3#update'
  delete '/apps/:guid', to: 'apps_v3#destroy'
  put '/apps/:guid/start', to: 'apps_v3#start'
  put '/apps/:guid/stop', to: 'apps_v3#stop'
  get '/apps/:guid/env', to: 'apps_v3#show_environment'
  put '/apps/:guid/droplets/current', to: 'apps_v3#assign_current_droplet'
  get '/apps/:guid/droplets/current', to: 'apps_v3#current_droplet'

  # processes
  get '/processes', to: 'processes#index'
  get '/processes/:process_guid', to: 'processes#show'
  patch '/processes/:process_guid', to: 'processes#update'
  delete '/processes/:process_guid/instances/:index', to: 'processes#terminate'
  put '/processes/:process_guid/scale', to: 'processes#scale'
  get '/processes/:process_guid/stats', to: 'processes#stats'
  get '/apps/:app_guid/processes', to: 'processes#index'
  get '/apps/:app_guid/processes/:type', to: 'processes#show'
  put '/apps/:app_guid/processes/:type/scale', to: 'processes#scale'
  delete '/apps/:app_guid/processes/:type/instances/:index', to: 'processes#terminate'
  get '/apps/:app_guid/processes/:type/stats', to: 'processes#stats'

  # packages
  get '/packages', to: 'packages#index'
  get '/packages/:guid', to: 'packages#show'
  post '/packages/:guid/upload', to: 'packages#upload'
  get '/packages/:guid/download', to: 'packages#download'
  delete '/packages/:guid', to: 'packages#destroy'
  get '/apps/:app_guid/packages', to: 'packages#index'
  post '/apps/:app_guid/packages', to: 'packages#create'

  # droplets
  post '/packages/:package_guid/droplets', to: 'droplets#create'
  post '/droplets/:guid/copy', to: 'droplets#copy'
  get '/droplets', to: 'droplets#index'
  get '/droplets/:guid', to: 'droplets#show'
  delete '/droplets/:guid', to: 'droplets#destroy'
  get '/apps/:app_guid/droplets', to: 'droplets#index'
  get '/packages/:package_guid/droplets', to: 'droplets#index'

  # route_mappings
  post '/route_mappings', to: 'route_mappings#create'
  get '/route_mappings', to: 'route_mappings#index'
  get '/route_mappings/:route_mapping_guid', to: 'route_mappings#show'
  delete '/route_mappings/:route_mapping_guid', to: 'route_mappings#destroy'
  get '/apps/:app_guid/route_mappings', to: 'route_mappings#index'

  # tasks
  get '/tasks', to: 'tasks#index'
  get '/tasks/:task_guid', to: 'tasks#show'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel'

  post '/apps/:app_guid/tasks', to: 'tasks#create'
  get '/apps/:app_guid/tasks', to: 'tasks#index'

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
