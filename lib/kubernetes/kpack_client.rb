require 'kubernetes/kube_client_builder'

module Kubernetes
  class KpackClient
    def initialize(kube_client)
      @client = kube_client
    end

    def create_image(*args)
      @client.create_image(*args)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageError', 'create', e.message)
    end

    def get_image(name, namespace)
      @client.get_image(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    end

    def update_image(*args)
      @client.update_image(*args)
    end
  end
end
