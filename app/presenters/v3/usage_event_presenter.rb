require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class UsageEventPresenter < BasePresenter
    def to_hash
      {
        guid: usage_event.guid,
        created_at: usage_event.created_at,
        updated_at: usage_event.updated_at,
        type: usage_event.type,
        data: build_data
      }
    end

    private

    def usage_event
      @resource
    end

    def build_data
      if usage_event.type == 'app'
        build_app_data
      end
    end

    def build_app_data
      {
        state: {
          current: usage_event.state,
          previous: usage_event.previous_state,
        },
        app: {
          guid: usage_event.parent_app_guid,
          name: usage_event.parent_app_name,
        },
        process: {
          guid: usage_event.app_guid,
          type: usage_event.process_type,
        },
        space: {
          guid: usage_event.space_guid,
          name: usage_event.space_name,
        },
        organization: {
          guid: usage_event.org_guid,
        },
        buildpack: {
          guid: usage_event.buildpack_guid,
          name: usage_event.buildpack_name,
        },
        task: {
          guid: usage_event.task_guid,
          name: usage_event.task_name,
        },
        memory_in_mb_per_instance: {
          current: usage_event.memory_in_mb_per_instance,
          previous: usage_event.previous_memory_in_mb_per_instance
        },
        instance_count: {
          current: usage_event.instance_count,
          previous: usage_event.previous_instance_count,
        }
      }
    end
  end
end
