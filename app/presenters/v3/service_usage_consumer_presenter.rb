require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class ServiceUsageConsumerPresenter < BasePresenter
    def to_hash
      {
        guid: service_usage_consumer.consumer_guid,
        last_processed_guid: service_usage_consumer.last_processed_guid,
        created_at: service_usage_consumer.created_at,
        updated_at: service_usage_consumer.updated_at,
        links: build_links
      }
    end

    private

    def service_usage_consumer
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/service_usage_consumers/#{service_usage_consumer.consumer_guid}")
        }
      }
    end
  end
end
