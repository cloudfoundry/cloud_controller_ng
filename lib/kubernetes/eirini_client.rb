require 'steno'
require 'kubernetes/kube_client_builder'
require 'cloud_controller/errors/api_error'

module Kubernetes
  class EiriniClient
    class Error < StandardError; end
    class ConflictError < Error; end

    def initialize(eirini_kube_client:)
      @eirini_kube_client = eirini_kube_client
    end

    def create_lrp(resource_config)
      @eirini_kube_client.create_lrp(resource_config)
    rescue Kubeclient::HttpError => e
      logger.error('create_lrp', error: e.inspect, response: e.response, backtrace: e.backtrace, resource: resource_config)
      raise CloudController::Errors::ApiError.new_from_details('EiriniLRPError', 'create', e.message)
    end

    private

    def logger
      Steno.logger('kubernetes.eirini_client')
    end
  end
end
