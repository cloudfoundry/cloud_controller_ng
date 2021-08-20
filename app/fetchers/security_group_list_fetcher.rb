require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'
require 'fetchers/base_list_fetcher'
require 'fetchers/security_group_fetcher'

module VCAP::CloudController
  class SecurityGroupListFetcher < BaseListFetcher
    class << self
      def fetch_all(message)
        dataset = SecurityGroup.dataset
        dataset = SecurityGroupFetcher.eager_load_running_and_staging_space_guids(dataset)
        filter(message, dataset)
      end

      def fetch(message, visible_security_group_guids)
        dataset = SecurityGroup.where(guid: visible_security_group_guids)
        dataset = SecurityGroupFetcher.eager_load_running_and_staging_space_guids(dataset)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
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

        super(message, dataset, SecurityGroup)
      end
    end
  end
end
