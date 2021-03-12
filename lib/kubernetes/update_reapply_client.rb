require 'retryable'

module Kubernetes
  class UpdateReapplyClient
    class Error < StandardError; end
    class MalformedBlockError < Error; end

    UPDATE_CONFLICT_RETRIES = 3

    def initialize(api_client)
      @client = api_client
    end

    def apply_route_update(name, namespace, &block)
      raise MalformedBlockError if block.arity != 1

      retry_on_conflict do
        @client.update_route(block.call(@client.get_route(name, namespace)))
      end
    end

    def apply_image_update(name, namespace, &block)
      raise MalformedBlockError if block.arity != 1

      retry_on_conflict do
        VCAP::CloudController::DropletModel.db.transaction do
          @client.update_image(block.call(@client.get_image(name, namespace)))
        end
      end
    end

    def apply_builder_update(name, namespace, &block)
      raise MalformedBlockError if block.arity != 1

      retry_on_conflict do
        @client.update_builder(block.call(@client.get_builder(name, namespace)))
      end
    end

    private

    def retry_on_conflict
      # maybe exponential backoff would be nice
      Retryable.retryable(sleep: 0, tries: UPDATE_CONFLICT_RETRIES, on: ApiClient::ConflictError) do |retries, exception|
        logger.error("Failed to resolve update conflicts after #{UPDATE_CONFLICT_RETRIES} retries: #{exception}") if retries == UPDATE_CONFLICT_RETRIES
        yield(retries, exception)
      end
    end

    def logger
      Steno.logger('kubernetes.update_reapply')
    end
  end
end
