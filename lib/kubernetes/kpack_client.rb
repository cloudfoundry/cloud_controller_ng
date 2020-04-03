require 'kubernetes/kube_client_builder'

module Kubernetes
  class KpackClient
    def initialize(kube_client)
      @client = kube_client
    end

    def create_image(*args)
      @client.create_image(*args)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('KpackImageCreateError', e.message)
    end
  end
end
