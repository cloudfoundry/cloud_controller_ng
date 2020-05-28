require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class UsageEventPresenter < BasePresenter
    def to_hash
      {
        guid: usage_event.guid,
        created_at: usage_event.created_at,
        updated_at: usage_event.updated_at,
        type: usage_event.type,
      }
    end

    private

    def usage_event
      @resource
    end
  end
end
