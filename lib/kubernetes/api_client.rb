require 'kubernetes/kube_client_builder'

module Kubernetes
  class ApiClient
    def initialize(build_kube_client:, kpack_kube_client:, route_kube_client:)
      @build_kube_client = build_kube_client
      @kpack_kube_client = kpack_kube_client
      @route_kube_client = route_kube_client
    end

    def create_image(resource_config)
      @build_kube_client.create_image(resource_config)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageError', 'create', e.message)
    end

    def get_image(name, namespace)
      @build_kube_client.get_image(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageError', 'get', e.message)
    end

    def update_image(resource_config)
      @build_kube_client.update_image(resource_config)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageError', 'update', e.message)
    end

    def delete_image(name, namespace)
      @build_kube_client.delete_image(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageError', 'delete', e.message)
    end

    def create_route(resource_config)
      @route_kube_client.create_route(resource_config)
    rescue Kubeclient::HttpError => e
      error = CloudController::Errors::ApiError.new_from_details('KubernetesRouteResourceError', resource_name(resource_config))
      error.set_backtrace(e.backtrace)
      raise error
    end

    def get_route(name, namespace)
      @route_kube_client.get_route(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      error = CloudController::Errors::ApiError.new_from_details('KubernetesRouteResourceError', name)
      error.set_backtrace(e.backtrace)
      raise error
    end

    def update_route(resource_config)
      @route_kube_client.update_route(resource_config)
    rescue Kubeclient::HttpError => e
      logger.error('update_route', error: e.inspect, response: e.response)
      error = CloudController::Errors::ApiError.new_from_details('KubernetesRouteResourceError', resource_name(resource_config), e.message, e.response)
      error.set_backtrace(e.backtrace)
      raise error
    end

    def delete_route(name, namespace)
      @route_kube_client.delete_route(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      error = CloudController::Errors::ApiError.new_from_details('KubernetesRouteResourceError', name)
      error.set_backtrace(e.backtrace)
      raise error
    end

    def get_custom_builder(name, namespace)
      @kpack_kube_client.get_custom_builder(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackCustomBuilderError', 'get', e.message)
    end

    private

    def logger
      Steno.logger('kubernetes.api_client')
    end

    def resource_name(resource_config)
      resource_metadata = resource_config.to_hash.symbolize_keys[:metadata] || {}
      resource_metadata.fetch(:name, '')
    end
  end
end
