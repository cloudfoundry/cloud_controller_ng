require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'

module VCAP::CloudController
  class SecurityGroupListFetcher
    class << self
      def fetch_all(message)
        dataset = SecurityGroup.dataset
        filter(message, dataset)
      end

      def fetch(message, visible_security_group_guids)
        dataset = SecurityGroup.where(guid: visible_security_group_guids)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        if message.requested?(:names)
          dataset = dataset.where(name: message.names)
        end

        if message.requested?(:staging_space_guids)
          space_dataset = Space.where(guid: message.staging_space_guids)
          dataset = dataset.where(staging_spaces: space_dataset)
        end

        if message.requested?(:running_space_guids)
          space_dataset = Space.where(guid: message.running_space_guids)
          dataset = dataset.where(spaces: space_dataset)
        end

        if message.requested?(:globally_enabled_running)
          dataset = dataset.where(running_default: ActiveModel::Type::Boolean.new.cast(message.globally_enabled_running))
        end

        if message.requested?(:globally_enabled_staging)
          dataset = dataset.where(staging_default: ActiveModel::Type::Boolean.new.cast(message.globally_enabled_staging))
        end

        dataset
      end
    end
  end
end
