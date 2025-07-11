Rails.application.routes.draw do
  get '/', to: 'root#v3_root'

  # admin actions
  post '/admin/actions/clear_buildpack_cache', to: 'admin_actions#clear_buildpack_cache'

  # apps
  get '/apps', to: 'apps_v3#index'
  post '/apps', to: 'apps_v3#create'
  get '/apps/:guid', to: 'apps_v3#show'
  patch '/apps/:guid', to: 'apps_v3#update'
  delete '/apps/:guid', to: 'apps_v3#destroy'
  post '/apps/:guid/actions/start', to: 'apps_v3#start'
  post '/apps/:guid/actions/stop', to: 'apps_v3#stop'
  post '/apps/:guid/actions/restart', to: 'apps_v3#restart'
  post '/apps/:guid/actions/clear_buildpack_cache', to: 'apps_v3#clear_buildpack_cache'
  get '/apps/:guid/env', to: 'apps_v3#show_env'
  get '/apps/:guid/permissions', to: 'apps_v3#show_permissions'
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
  post '/deployments/:guid/actions/continue', to: 'deployments#continue'

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
  get '/droplets/:guid/download', to: 'droplets#download'

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
  get '/organizations/:guid/users', to: 'organizations_v3#list_members'

  # organization_quotas
  post '/organization_quotas', to: 'organization_quotas#create'
  get  '/organization_quotas/:guid', to: 'organization_quotas#show'
  get  '/organization_quotas', to: 'organization_quotas#index'
  patch '/organization_quotas/:guid', to: 'organization_quotas#update'
  delete '/organization_quotas/:guid', to: 'organization_quotas#destroy'
  post '/organization_quotas/:guid/relationships/organizations', to: 'organization_quotas#apply_to_organizations'

  # resource_matches
  post '/resource_matches', to: 'resource_matches#create'

  # routes
  get '/routes', to: 'routes#index'
  get '/routes/:guid', to: 'routes#show'
  post '/routes', to: 'routes#create'
  post '/routes/:guid/relationships/shared_spaces', to: 'routes#share_routes'
  delete '/routes/:guid/relationships/shared_spaces/:space_guid', to: 'routes#unshare_route'
  get '/routes/:guid/relationships/shared_spaces', to: 'routes#relationships_shared_routes'
  patch '/routes/:guid/relationships/space', to: 'routes#transfer_owner'
  patch '/routes/:guid', to: 'routes#update'
  delete '/routes/:guid', to: 'routes#destroy'
  get '/apps/:guid/routes', to: 'routes#index_by_app'

  # destinations
  get '/routes/:guid/destinations', to: 'routes#index_destinations'
  post '/routes/:guid/destinations', to: 'routes#insert_destinations'
  patch '/routes/:guid/destinations', to: 'routes#replace_destinations'
  delete '/routes/:guid/destinations/:destination_guid', to: 'routes#destroy_destination'
  patch '/routes/:guid/destinations/:destination_guid', to: 'routes#update_destination'

  # security_groups
  post '/security_groups', to: 'security_groups#create'
  post '/security_groups/:guid/relationships/running_spaces', to: 'security_groups#create_running_spaces'
  post '/security_groups/:guid/relationships/staging_spaces', to: 'security_groups#create_staging_spaces'
  get '/security_groups/:guid', to: 'security_groups#show'
  get '/security_groups', to: 'security_groups#index'
  patch '/security_groups/:guid', to: 'security_groups#update'
  delete '/security_groups/:guid/relationships/running_spaces/:space_guid', to: 'security_groups#delete_running_spaces'
  delete '/security_groups/:guid/relationships/staging_spaces/:space_guid', to: 'security_groups#delete_staging_spaces'
  delete '/security_groups/:guid', to: 'security_groups#destroy'

  # service_bindings
  post '/service_bindings', to: 'service_bindings#create'
  get '/service_bindings/:guid', to: 'service_bindings#show'
  get '/service_bindings', to: 'service_bindings#index'
  delete '/service_bindings/:guid', to: 'service_bindings#destroy'

  # service_credential_bindings
  resources :service_credential_bindings,
            param: :guid,
            only: %i[create show index update destroy] do
    member do
      get :details
      get :parameters
    end
  end

  # service_route_bindings
  resources :service_route_bindings,
            param: :guid,
            only: %i[create show index update destroy] do
    member do
      get :parameters
    end
  end

  # service_brokers
  get '/service_brokers', to: 'service_brokers#index'
  get '/service_brokers/:guid', to: 'service_brokers#show'
  post '/service_brokers', to: 'service_brokers#create'
  patch '/service_brokers/:guid', to: 'service_brokers#update'
  delete '/service_brokers/:guid', to: 'service_brokers#destroy'

  # service_offerings
  get '/service_offerings', to: 'service_offerings#index'
  get '/service_offerings/:guid', to: 'service_offerings#show'
  patch '/service_offerings/:guid', to: 'service_offerings#update'
  delete '/service_offerings/:guid', to: 'service_offerings#destroy'

  # service_plans
  get '/service_plans', to: 'service_plans#index'
  get '/service_plans/:guid', to: 'service_plans#show'
  patch '/service_plans/:guid', to: 'service_plans#update'
  delete '/service_plans/:guid', to: 'service_plans#destroy'

  # service_plan_visibility
  get '/service_plans/:guid/visibility', to: 'service_plan_visibility#show'
  patch '/service_plans/:guid/visibility', to: 'service_plan_visibility#update'
  post '/service_plans/:guid/visibility', to: 'service_plan_visibility#apply'
  delete '/service_plans/:guid/visibility/:org_guid', to: 'service_plan_visibility#destroy'

  # service_instances
  get '/service_instances', to: 'service_instances_v3#index'
  get '/service_instances/:guid', to: 'service_instances_v3#show'
  get '/service_instances/:guid/relationships/shared_spaces', to: 'service_instances_v3#relationships_shared_spaces'
  get '/service_instances/:guid/relationships/shared_spaces/usage_summary', to: 'service_instances_v3#shared_spaces_usage_summary'
  get '/service_instances/:guid/credentials', to: 'service_instances_v3#credentials'
  get '/service_instances/:guid/parameters', to: 'service_instances_v3#parameters'
  get '/service_instances/:guid/permissions', to: 'service_instances_v3#show_permissions'
  post '/service_instances', to: 'service_instances_v3#create'
  post '/service_instances/:guid/relationships/shared_spaces', to: 'service_instances_v3#share_service_instance'
  patch '/service_instances/:guid', to: 'service_instances_v3#update'
  delete '/service_instances/:guid', to: 'service_instances_v3#destroy'
  delete '/service_instances/:guid/relationships/shared_spaces/:space_guid', to: 'service_instances_v3#unshare_service_instance'

  # space_features
  get '/spaces/:guid/features/:name', to: 'space_features#show'
  get '/spaces/:guid/features', to: 'space_features#index'
  patch '/spaces/:guid/features/:name', to: 'space_features#update'

  # space_manifests
  post '/spaces/:guid/actions/apply_manifest', to: 'space_manifests#apply_manifest'
  post '/spaces/:guid/manifest_diff', to: 'space_manifests#diff_manifest'

  # space_quotas
  post '/space_quotas', to: 'space_quotas#create'
  get '/space_quotas/:guid', to: 'space_quotas#show'
  get '/space_quotas', to: 'space_quotas#index'
  patch '/space_quotas/:guid', to: 'space_quotas#update'
  post '/space_quotas/:guid/relationships/spaces', to: 'space_quotas#apply_to_spaces'
  delete '/space_quotas/:guid/relationships/spaces/:space_guid', to: 'space_quotas#remove_from_space'
  delete '/space_quotas/:guid', to: 'space_quotas#destroy'

  # spaces
  post '/spaces', to: 'spaces_v3#create'
  get '/spaces', to: 'spaces_v3#index'
  get '/spaces/:guid', to: 'spaces_v3#show'
  get '/spaces/:guid/running_security_groups', to: 'spaces_v3#running_security_groups'
  get '/spaces/:guid/staging_security_groups', to: 'spaces_v3#staging_security_groups'
  patch '/spaces/:guid', to: 'spaces_v3#update'
  delete 'spaces/:guid', to: 'spaces_v3#destroy'
  delete 'spaces/:guid/routes', to: 'spaces_v3#delete_unmapped_routes'
  get '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#show_isolation_segment'
  patch '/spaces/:guid/relationships/isolation_segment', to: 'spaces_v3#update_isolation_segment'
  get '/spaces/:guid/users', to: 'spaces_v3#list_members'

  # tasks
  get '/tasks', to: 'tasks#index'
  get '/tasks/:task_guid', to: 'tasks#show'
  put '/tasks/:task_guid/cancel', to: 'tasks#cancel'
  post '/tasks/:task_guid/actions/cancel', to: 'tasks#cancel'
  patch '/tasks/:task_guid', to: 'tasks#update'

  post '/apps/:app_guid/tasks', to: 'tasks#create'
  get '/apps/:app_guid/tasks', to: 'tasks#index'

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

  # app usage events
  get '/app_usage_events', to: 'app_usage_events#index'
  get '/app_usage_events/:guid', to: 'app_usage_events#show'
  post '/app_usage_events/actions/destructively_purge_all_and_reseed', to: 'app_usage_events#destructively_purge_all_and_reseed'

  # service usage events
  get '/service_usage_events', to: 'service_usage_events#index'
  get '/service_usage_events/:guid', to: 'service_usage_events#show'
  post '/service_usage_events/actions/destructively_purge_all_and_reseed', to: 'service_usage_events#destructively_purge_all_and_reseed'

  # app usage consumers
  get '/app_usage_consumers', to: 'app_usage_consumers#index'
  get '/app_usage_consumers/:guid', to: 'app_usage_consumers#show'
  delete '/app_usage_consumers/:guid', to: 'app_usage_consumers#destroy'

  # service usage consumers
  get '/service_usage_consumers', to: 'service_usage_consumers#index'
  get '/service_usage_consumers/:guid', to: 'service_usage_consumers#show'
  delete '/service_usage_consumers/:guid', to: 'service_usage_consumers#destroy'

  # environment variable groups
  get '/environment_variable_groups/:name', to: 'environment_variable_groups#show'
  patch '/environment_variable_groups/:name', to: 'environment_variable_groups#update'

  # roles
  get '/roles', to: 'roles#index'
  get '/roles/:guid', to: 'roles#show'
  post '/roles', to: 'roles#create'
  delete '/roles/:guid', to: 'roles#destroy'

  # info
  get '/info', to: 'info#v3_info'
  get '/info/usage_summary', to: 'info#show_usage_summary'

  namespace :internal do
    patch '/builds/:guid', to: 'builds#update'
  end
end
