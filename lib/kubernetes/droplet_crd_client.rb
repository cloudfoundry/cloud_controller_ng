require 'kubernetes/kube_client_builder'

module Kubernetes
  class DropletCrdClient
    def initialize(kube_client)
      @client = kube_client
    end

    def client
      @client
    end

    def create_droplet(*args)
      @client.create_droplet(*args)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('DropletError', 'create', e.message)
    end

    def get_droplet(name, namespace)
      @client.get_droplet(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('DropletError', 'get', e.message)
    end

    def update_droplet(*args)
      @client.update_droplet(*args)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('DropletError', 'update', e.message)
    end

    def patch_droplet(*args)
      @client.merge_patch_droplet(*args)
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('DropletError', 'patch', e.message)
    end

    def delete_droplet(name, namespace)
      @client.delete_droplet(name, namespace)
    rescue Kubeclient::ResourceNotFoundError
      nil
    rescue Kubeclient::HttpError => e
      raise CloudController::Errors::ApiError.new_from_details('DropletError', 'delete', e.message)
    end
  end
end
