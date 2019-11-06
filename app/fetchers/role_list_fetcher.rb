require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class RoleListFetcher
    class << self
      def fetch(message, readable_users_dataset)
        filter(message, readable_users_dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end
        if message.requested?(:types)
          dataset = dataset.where(type: message.types)
        end
        if message.requested?(:organization_guids)
          org_ids = Organization.dataset.where(guid: message.organization_guids).select(:id)
          dataset = dataset.where(organization_id: org_ids)
        end
        if message.requested?(:user_guids)
          user_ids = User.dataset.where(guid: message.user_guids).select(:id)
          dataset = dataset.where(user_id: user_ids)
        end
        if message.requested?(:space_guids)
          space_ids = Space.dataset.where(guid: message.space_guids).select(:id)
          dataset = dataset.where(space_id: space_ids)
        end
        dataset
      end
    end
  end
end
