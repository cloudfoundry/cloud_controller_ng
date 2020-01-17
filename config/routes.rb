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
  post '/apps/:guid/actions/restart', to: 'apps_v3#restart'
  get '/apps/:guid/env', to: 'apps_v3#show_env'
  get '/apps/:guid/builds', to: 'apps_v3#builds'
  patch '/apps/:guid/relationships/current_droplet', to: 'apps_v3#assign_current_droplet'
  get '/apps/:guid/relationships/current_droplet', to: 'apps_v3#current_droplet_relationship'
  get '/apps/:guid/droplets/current', to: 'apps_v3#current_droplet'

  # app features
  get '/apps/:app_guid/features', to: 'app_features#index'
  get '/apps/:app_guid/features/:name', to: 'app_features#show'
  patch '/apps/:app_guid/features/:name', to: 'app_features#update'
  get '/apps/:guid/ssh_enabled', to: 'app_features#ssh_enabled'

  # app manifests
  post '/apps/:guid/actions/apply_manifest', to: 'app_manifests#apply_manifest'
  get '/apps/:guid/manifest', to: 'app_manifests#show'

  # app revisions
  get '/apps/:guid/revisions', to: 'app_revisions#index'
  get '/apps/:guid/revisions/deployed', to: 'app_revisions#deployed'

  # app sidecars
  post '/apps/:guid/sidecars', to: 'sidecars#create'
  get '/sidecars/:guid', to: 'sidecars#show'
  get '/processes/:process_guid/sidecars', to: 'sidecars#index_by_process'
  get '/apps/:app_guid/sidecars', to: 'sidecars#index_by_app'
  patch '/sidecars/:guid', to: 'sidecars#update'
  delete '/sidecars/:guid', to: 'sidecars#destroy'

  # revisions
  get '/revisions/:revision_guid/environment_variables', to: 'revisions#show_environment_variables'
  patch '/revisions/:revision_guid', to: 'revisions#update'
  get '/revisions/:revision_guid', to: 'revisions#show'

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
  patch '/packages/:guid', to: 'packages#update'
  post '/packages/:guid/upload', to: 'packages#upload'
  post '/packages', to: 'packages#create'
  get '/packages/:guid/download', to: 'packages#download'
  delete '/packages/:guid', to: 'packages#destroy'
  get '/apps/:app_guid/packages', to: 'packages#index'

  # builds
  post '/builds', to: 'builds#create'
  get '/builds', to: 'builds#index'
  patch '/builds/:guid', to: 'builds#update'
  get '/builds/:guid', to: 'builds#show'

  # deployments
  post '/deployments', to: 'deployments#create'
  patch '/deployments/:guid', to: 'deployments#update'
  get '/deployments/', to: 'deployments#index'
  get '/deployments/:guid', to: 'deployments#show'
  post '/deployments/:guid/actions/cancel', to: 'deployments#cancel'

  # domains
  post '/domains', to: 'domains#create'
  get '/domains', to: 'domains#index'
  get '/domains/:guid', to: 'domains#show'
  delete '/domains/:guid', to: 'domains#destroy'
  post '/domains/:guid/relationships/shared_organizations', to: 'domains#update_shared_orgs'
  delete '/domains/:guid/relationships/shared_organizations/:org_guid', to: 'domains#delete_shared_org'
  patch '/domains/:guid', to: 'domains#update'
  get 'domains/:guid/route_reservations', to: 'domains#check_routes'

  # droplets
  post '/droplets', to: 'droplets#create'
  get '/droplets', to: 'droplets#index'
  get '/droplets/:guid', to: 'droplets#show'
  delete '/droplets/:guid', to: 'droplets#destroy'
  get '/apps/:app_guid/droplets', to: 'droplets#index'
  get '/packages/:package_guid/droplets', to: 'droplets#index'
  patch '/droplets/:guid', to: 'droplets#update'
  post '/droplets/:guid/upload', to: 'droplets#upload'

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
  patch '/organizations/:guid', to: 'organizations_v3#update'
  get '/organizations/:guid/domains', to: 'organizations_v3#index_org_domains'
  get '/organizations/:guid/domains/default', to: 'organizations_v3#show_default_domain'
  get '/organizations/:guid/usage_summary', to: 'organizations_v3#show_usage_summary'
  get '/organizations', to: 'organizations_v3#index'
  get '/isolation_segments/:isolation_segment_guid/organizations', to: 'organizations_v3#index'
  get '/organizations/:guid/relationships/default_isolation_segment', to: 'organizations_v3#show_default_isolation_segment'
  patch '/organizations/:guid/relationships/default_isolation_segment', to: 'organizations_v3#update_default_isolation_segment'
  delete '/organizations/:guid', to: 'organizations_v3#destroy'

  # organization_quotas
  post '/organization_quotas', to: 'organization_quotas#create'
  get  '/organization_quotas/:guid', to: 'organization_quotas#show'
  get  '/organization_quotas', to: 'organization_quotas#index'
  patch '/organization_quotas/:guid', to: 'organization_quotas#update'

  # resource_matches
  post '/resource_matches', to: 'resource_matches#create'

  # routes
  get '/routes', to: 'routes#index'
  get '/routes/:guid', to: 'routes#show'
  post '/routes', to: 'routes#create'
  patch '/routes/:guid', to: 'routes#update'
  delete '/routes/:guid', to: 'routes#destroy'
  get '/apps/:guid/routes', to: 'routes#index_by_app'

  # destinations
  get '/routes/:guid/destinations', to: 'routes#index_destinations'
  post '/routes/:guid/destinations', to: 'routes#insert_destinations'
  patch '/routes/:guid/destinations', to: 'routes#replace_destinations'
  delete '/routes/:guid/destinations/:destination_guid', to: 'routes#destroy_destination'

  # service_bindings
  post '/service_bindings', to: 'service_bindings#create'
  get '/service_bindings/:guid', to: 'service_bindings#show'
  get '/service_bindings', to: 'service_bindings#index'
  delete '/service_bindings/:guid', to: 'service_bindings#destroy'

  # service_brokers
  get '/service_brokers', to: 'service_brokers#index'
  get '/service_brokers/:guid', to: 'service_brokers#show'
  post '/service_brokers', to: 'service_brokers#create'
  patch '/service_brokers/:guid', to: 'service_brokers#update'
  delete '/service_brokers/:guid', to: 'service_brokers#destroy'

  # service_offerings
  get '/service_offerings', to: 'service_offerings#index'
  get '/service_offerings/:guid', to: 'service_offerings#show'

  # space_manifests
  post '/spaces/:guid/actions/apply_manifest', to: 'space_manifests#apply_manifest'

  # space_quotas
  post '/space_quotas', to: 'space_quotas#create'

  # spaces
  post '/spaces', to: 'spaces_v3#create'
  get '/spaces', to: 'spaces_v3#index'
  get '/spaces/:guid', to: 'spaces_v3#show'
  patch '/spaces/:guid', to: 'spaces_v3#update'
  delete 'spaces/:guid', to: 'spaces_v3#destroy'
  delete 'spaces/:guid/routes', to: 'spaces_v3#delete_unmapped_routes'
  get '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#show_isolation_segment'
  patch '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#update_isolation_segment'

  # tasks
  get '/tasks', to: 'tasks#index'
  get '/tasks/:task_guid', to: 'tasks#show'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel'
  post '/tasks/:task_guid/actions/cancel', to: 'tasks#cancel'
  patch '/tasks/:task_guid', to: 'tasks#update'

  post '/apps/:app_guid/tasks', to: 'tasks#create'
  get '/apps/:app_guid/tasks', to: 'tasks#index'

  # service_instances
  get '/service_instances', to: 'service_instances_v3#index'
  get '/service_instances/:service_instance_guid/relationships/shared_spaces', to: 'service_instances_v3#relationships_shared_spaces'
  post '/service_instances/:service_instance_guid/relationships/shared_spaces', to: 'service_instances_v3#share_service_instance'
  patch '/service_instances/:guid', to: 'service_instances_v3#update'
  delete '/service_instances/:service_instance_guid/relationships/shared_spaces/:space_guid', to: 'service_instances_v3#unshare_service_instance'

  # stacks
  get '/stacks', to: 'stacks#index'
  get '/stacks/:guid', to: 'stacks#show'
  get '/stacks/:guid/apps', to: 'stacks#show_apps'
  post '/stacks', to: 'stacks#create'
  patch '/stacks/:guid', to: 'stacks#update'
  delete '/stacks/:guid', to: 'stacks#destroy'

  # users
  get '/users', to: 'users#index'
  get '/users/:guid', to: 'users#show'
  post '/users', to: 'users#create'
  patch '/users/:guid', to: 'users#update'
  delete '/users/:guid', to: 'users#destroy'

  # buildpacks
  get '/buildpacks', to: 'buildpacks#index'
  get '/buildpacks/:guid', to: 'buildpacks#show'
  post '/buildpacks', to: 'buildpacks#create'
  patch '/buildpacks/:guid', to: 'buildpacks#update'
  delete '/buildpacks/:guid', to: 'buildpacks#destroy'
  post '/buildpacks/:guid/upload', to: 'buildpacks#upload'

  # feature flags
  get '/feature_flags', to: 'feature_flags#index'
  get '/feature_flags/:name', to: 'feature_flags#show'
  patch '/feature_flags/:name', to: 'feature_flags#update'

  # audit events
  get '/audit_events', to: 'events#index'
  get '/audit_events/:guid', to: 'events#show'

  # environment variable groups
  get '/environment_variable_groups/:name', to: 'environment_variable_groups#show'
  patch '/environment_variable_groups/:name', to: 'environment_variable_groups#update'

  # roles
  get '/roles', to: 'roles#index'
  get '/roles/:guid', to: 'roles#show'
  post '/roles', to: 'roles#create'
  delete '/roles/:guid', to: 'roles#destroy'

  # info
  get '/info', to: 'info#show'

  namespace :internal do
    patch '/builds/:guid', to: 'builds#update'
  end
end
