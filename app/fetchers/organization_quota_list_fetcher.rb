require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class OrganizationQuotaListFetcher < BaseListFetcher
    class << self
      def fetch(message:, readable_org_guids_query:)
        dataset = QuotaDefinition.dataset
        filter(message, dataset, readable_org_guids_query)
      end

      def fetch_all(message:)
        dataset = QuotaDefinition.dataset
        filter(message, dataset)
      end

      private

      def filter(message, dataset, readable_org_guids_query=nil)
        if message.requested? :names
          dataset = dataset.where(name: message.names)
        end

        if message.requested? :organization_guids
          dataset = dataset.
                    join(:organizations, quota_definition_id: :id).
                    where(organizations__guid: message.organization_guids).distinct.
                    qualify(:quota_definitions)

          dataset = dataset.where(organizations__guid: readable_org_guids_query) if readable_org_guids_query
        end

        super(message, dataset, QuotaDefinition)
      end
    end
  end
end
