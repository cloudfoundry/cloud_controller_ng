require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/tps_client'

module VCAP::CloudController
  class BulkAppsController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details('NotAuthenticated')
      end
    end

    def bulk_apps
      batch_size = Integer(params.fetch('batch_size'))
      bulk_token = MultiJson.load(params.fetch('token'))
      last_id = Integer(bulk_token['id'] || 0)

      if params['format'] == 'fingerprint'
        bulk_fingerprint_format(batch_size, last_id)
      else
        bulk_desire_app_format(batch_size, last_id)
      end
    rescue IndexError => e
      raise ApiError.new_from_details('BadQueryParameter', e.message)
    end

    get '/internal/bulk/apps', :bulk_apps

    def filtered_bulk_apps
      raise ApiError.new_from_details('MessageParseError', 'Missing request body') if body.length == 0
      payload = MultiJson.load(body)

      apps = runners.diego_apps_from_process_guids(payload)
      messages = apps.map { |app| runners.runner_for_app(app).desire_app_message }

      MultiJson.dump(messages)
    rescue MultiJson::ParseError => e
      raise ApiError.new_from_details('MessageParseError', e.message)
    end

    post '/internal/bulk/apps', :filtered_bulk_apps

    private

    def bulk_desire_app_format(batch_size, last_id)
      apps = runners.diego_apps(batch_size, last_id)
      messages = apps.map { |app| runners.runner_for_app(app).desire_app_message }
      id_for_next_token = apps.empty? ? nil : apps.last.id

      MultiJson.dump(
        apps: messages,
        token: { 'id' => id_for_next_token }
      )
    end

    def bulk_fingerprint_format(batch_size, last_id)
      id_for_next_token = nil
      messages = runners.diego_apps_cache_data(batch_size, last_id).map do |id, guid, version, updated|
        id_for_next_token = id
        { 'process_guid' => Diego::ProcessGuid.from(guid, version), 'etag' => updated.to_f.to_s }
      end

      MultiJson.dump(
        fingerprints: messages,
        token: { 'id' => id_for_next_token }
      )
    end

    def runners
      dependency_locator = ::CloudController::DependencyLocator.instance
      @runners ||= dependency_locator.runners
    end
  end
end
