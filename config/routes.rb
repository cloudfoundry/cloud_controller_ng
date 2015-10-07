Rails.application.routes.draw do
  resource :echo

  get '/processes', to: 'processes#index'
  get '/processes/:guid', to: 'processes#show'
  patch '/processes/:guid', to: 'processes#update', defaults: { format: :json }
  delete '/processes/:guid/instances/:index', to: 'processes#terminate', defaults: { format: :json }
  put '/processes/:guid/scale', to: 'processes#scale', defaults: { format: :json }

  get '/v3/processes', to: 'processes#index'
  get '/v3/processes/:guid', to: 'processes#show'
  patch '/v3/processes/:guid', to: 'processes#update', defaults: { format: :json }
  delete '/v3/processes/:guid/instances/:index', to: 'processes#terminate', defaults: { format: :json }
  put '/v3/processes/:guid/scale', to: 'processes#scale', defaults: { format: :json }
end
