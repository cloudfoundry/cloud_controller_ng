require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class ServiceUsageEventPresenter < BasePresenter
    def to_hash
      {
        guid: usage_event.guid,
        created_at: usage_event.created_at,
        updated_at: usage_event.created_at,
        state: usage_event.state,
        space: {
          guid: usage_event.space_guid,
          name: usage_event.space_name,
        },
        organization: {
          guid: usage_event.org_guid,
        },
        service_instance: {
          guid: usage_event.service_instance_guid,
          name: usage_event.service_instance_name,
          type: usage_event.service_instance_type,
        },
        service_plan: {
          guid: usage_event.service_plan_guid,
          name: usage_event.service_plan_name,
        },
        service_offering: {
          guid: usage_event.service_guid,
          name: usage_event.service_label,
        },
        service_broker: {
          guid: usage_event.service_broker_guid,
          name: usage_event.service_broker_name,
        },
        links: build_links
      }
    end

    private

    def usage_event
      @resource
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/service_usage_events/#{usage_event.guid}") }
      }
    end
  end
end
