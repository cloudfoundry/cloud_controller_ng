require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class SpaceQuotaListFetcher < BaseListFetcher
    class << self
      def fetch(message:, readable_space_quota_guids:)
        dataset = SpaceQuotaDefinition.dataset
        filter(message, dataset, readable_space_quota_guids)
      end

      private

      def filter(message, dataset, readable_space_quota_guids)
        dataset = dataset.where(guid: readable_space_quota_guids)

        if message.requested? :names
          dataset = dataset.where(name: message.names)
        end

        if message.requested? :organization_guids
          org_ids = Organization.where(guid: message.organization_guids).map(:id)
          dataset = dataset.where(organization_id: org_ids)
        end

        if message.requested? :space_guids
          dataset = dataset.
                    join(:spaces, space_quota_definition_id: :id).
                    where(Sequel[:spaces][:guid] => message.space_guids).distinct.
                    qualify(:space_quota_definitions)
        end

        super(message, dataset, SpaceQuotaDefinition)
      end
    end
  end
end
