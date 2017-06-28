require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/diego/tps_client'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/failure_reason_sanitizer'

module VCAP::CloudController
  class StagingCompletionController < RestController::BaseController
    def self.dependencies
      [:stagers]
    end

    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end
    end

    def inject_dependencies(dependencies)
      super
      @stagers = dependencies.fetch(:stagers)
    end

    post '/internal/v3/staging/:staging_guid/droplet_completed', :droplet_completed
    def droplet_completed(staging_guid)
      staging_response = read_body
      droplet          = DropletModel.find(guid: staging_guid)
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found') if droplet.nil?

      build = BuildModel.create(package: droplet.package, app: droplet.app, state: DropletModel::STAGING_STATE)

      BuildModel.db.transaction do
        build.lock!
        build.update(
          droplet: droplet,
          buildpack_lifecycle_data: droplet.buildpack_lifecycle_data
        )
      end

      if staging_response.key?(:failed)
        report_metrics(staging_response)
        staging_response = parse_bbs_task_callback(staging_response)
      end

      begin
        stagers.stager_for_app.staging_complete(build, staging_response, params['start'] == 'true')
      rescue CloudController::Errors::ApiError => api_err
        raise api_err
      rescue => e
        logger.error('diego.staging.completion-controller-error', error: e)
        raise CloudController::Errors::ApiError.new_from_details('ServerError')
      end

      [200, '{}']
    end

    post '/internal/v3/staging/:staging_guid/build_completed', :build_completed
    def build_completed(staging_guid)
      staging_response = read_body
      build            = BuildModel.find(guid: staging_guid)
      raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'Build not found') if build.nil?

      if staging_response.key?(:failed)
        report_metrics(staging_response)
        staging_response = parse_bbs_task_callback(staging_response)
      end

      begin
        stagers.stager_for_app.staging_complete(build, staging_response, params['start'] == 'true')
      rescue CloudController::Errors::ApiError => api_err
        logger.error('diego.staging.completion-controller-api_err-error', error: api_err)
        raise api_err
      rescue => e
        logger.error('diego.staging.completion-controller-error', error: e)
        raise CloudController::Errors::ApiError.new_from_details('ServerError')
      end

      [200, '{}']
    end

    private

    def parse_bbs_task_callback(staging_response)
      result = {}
      if staging_response[:failed]
        result[:error] = Diego::FailureReasonSanitizer.sanitize(staging_response[:failure_reason])
      else
        result[:result] = MultiJson.load(staging_response[:result], symbolize_keys: true)
      end
      result
    end

    def report_metrics(bbs_staging_response)
      duration = Time.now.utc.to_i * 1e9 - bbs_staging_response[:created_at]
      if bbs_staging_response[:failed]
        statsd_updater.report_staging_failure_metrics(duration)
      else
        statsd_updater.report_staging_success_metrics(duration)
      end
    end

    def statsd_updater
      @statsd_updater ||= VCAP::CloudController::Metrics::StatsdUpdater.new
    end

    attr_reader :stagers

    def read_body
      staging_response = {}
      begin
        payload          = body.read
        staging_response = MultiJson.load(payload, symbolize_keys: true)
      rescue MultiJson::ParseError => pe
        logger.error('diego.staging.parse-error', payload: payload, error: pe.to_s)
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      staging_response
    end
  end
end
