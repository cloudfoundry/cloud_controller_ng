Rails.application.routes.draw do
  get '/', to: 'root#v3_root'

  # apps
  get '/apps', to: 'apps_v3#index'
  post '/apps', to: 'apps_v3#create'
  get '/apps/:guid', to: 'apps_v3#show'
  patch '/apps/:guid', to: 'apps_v3#update'
  delete '/apps/:guid', to: 'apps_v3#destroy'
  post '/apps/:guid/actions/start', to: 'apps_v3#start'
  post '/apps/:guid/actions/stop', to: 'apps_v3#stop'
  get '/apps/:guid/env', to: 'apps_v3#show_env'
  patch '/apps/:guid/relationships/current_droplet', to: 'apps_v3#assign_current_droplet'
  get '/apps/:guid/relationships/current_droplet', to: 'apps_v3#current_droplet_relationship'
  get '/apps/:guid/droplets/current', to: 'apps_v3#current_droplet'
  get '/apps/:guid/features', to: 'apps_v3#features'

  # environment variables
  get '/apps/:guid/environment_variables', to: 'apps_v3#show_environment_variables'
  patch '/apps/:guid/environment_variables', to: 'apps_v3#update_environment_variables'

  # processes
  get '/processes', to: 'processes#index'
  get '/processes/:process_guid', to: 'processes#show'
  patch '/processes/:process_guid', to: 'processes#update'
  delete '/processes/:process_guid/instances/:index', to: 'processes#terminate'
  post '/processes/:process_guid/actions/scale', to: 'processes#scale'
  get '/processes/:process_guid/stats', to: 'processes#stats'
  get '/apps/:app_guid/processes', to: 'processes#index'
  get '/apps/:app_guid/processes/:type', to: 'processes#show'
  patch '/apps/:app_guid/processes/:type', to: 'processes#update'
  post '/apps/:app_guid/processes/:type/actions/scale', to: 'processes#scale'
  delete '/apps/:app_guid/processes/:type/instances/:index', to: 'processes#terminate'
  get '/apps/:app_guid/processes/:type/stats', to: 'processes#stats'

  # packages
  get '/packages', to: 'packages#index'
  get '/packages/:guid', to: 'packages#show'
  post '/packages/:guid/upload', to: 'packages#upload'
  post '/packages', to: 'packages#create'
  get '/packages/:guid/download', to: 'packages#download'
  delete '/packages/:guid', to: 'packages#destroy'
  get '/apps/:app_guid/packages', to: 'packages#index'

  # builds
  post '/builds', to: 'builds#create'
  get '/builds/:guid', to: 'builds#show'

  # droplets
  post '/packages/:package_guid/droplets', to: 'droplets#create'
  post '/droplets', to: 'droplets#copy'
  get '/droplets', to: 'droplets#index'
  get '/droplets/:guid', to: 'droplets#show'
  delete '/droplets/:guid', to: 'droplets#destroy'
  get '/apps/:app_guid/droplets', to: 'droplets#index'
  get '/packages/:package_guid/droplets', to: 'droplets#index'

  # errors
  match '404', to: 'errors#not_found', via: :all
  match '500', to: 'errors#internal_error', via: :all
  match '400', to: 'errors#bad_request', via: :all

  # isolation_segments
  post '/isolation_segments', to: 'isolation_segments#create'
  get '/isolation_segments', to: 'isolation_segments#index'
  get '/isolation_segments/:guid', to: 'isolation_segments#show'
  delete '/isolation_segments/:guid', to: 'isolation_segments#destroy'
  patch '/isolation_segments/:guid', to: 'isolation_segments#update'
  post '/isolation_segments/:guid/relationships/organizations', to: 'isolation_segments#assign_allowed_organizations'
  delete '/isolation_segments/:guid/relationships/organizations/:org_guid', to: 'isolation_segments#unassign_allowed_organization'

  get '/isolation_segments/:guid/relationships/organizations', to: 'isolation_segments#relationships_orgs'
  get '/isolation_segments/:guid/relationships/spaces', to: 'isolation_segments#relationships_spaces'

  # jobs
  get '/jobs/:guid', to: 'v3/jobs#show'

  # organizations
  post '/organizations', to: 'organizations_v3#create'
  get '/organizations/:guid', to: 'organizations_v3#show'
  get '/organizations', to: 'organizations_v3#index'
  get '/isolation_segments/:isolation_segment_guid/organizations', to: 'organizations_v3#index'
  get '/organizations/:guid/relationships/default_isolation_segment', to: 'organizations_v3#show_default_isolation_segment'
  patch '/organizations/:guid/relationships/default_isolation_segment', to: 'organizations_v3#update_default_isolation_segment'

  # route_mappings
  post '/route_mappings', to: 'route_mappings#create'
  get '/route_mappings', to: 'route_mappings#index'
  get '/route_mappings/:route_mapping_guid', to: 'route_mappings#show'
  delete '/route_mappings/:route_mapping_guid', to: 'route_mappings#destroy'
  get '/apps/:app_guid/route_mappings', to: 'route_mappings#index'

  # service_bindings
  post '/service_bindings', to: 'service_bindings#create'
  get '/service_bindings/:guid', to: 'service_bindings#show'
  get '/service_bindings', to: 'service_bindings#index'
  delete '/service_bindings/:guid', to: 'service_bindings#destroy'

  # spaces
  post '/spaces', to: 'spaces_v3#create'
  get '/spaces', to: 'spaces_v3#index'
  get '/spaces/:guid', to: 'spaces_v3#show'
  get '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#show_isolation_segment'
  patch '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#update_isolation_segment'

  # tasks
  get '/tasks', to: 'tasks#index'
  get '/tasks/:task_guid', to: 'tasks#show'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel'
  post '/tasks/:task_guid/actions/cancel', to: 'tasks#cancel'

  post '/apps/:app_guid/tasks', to: 'tasks#create'
  get '/apps/:app_guid/tasks', to: 'tasks#index'
end
