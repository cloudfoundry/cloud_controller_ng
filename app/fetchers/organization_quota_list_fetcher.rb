require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class OrganizationQuotaListFetcher < BaseListFetcher
    class << self
      def fetch(message:, readable_org_guids:)
        dataset = QuotaDefinition.dataset
        filter(message, dataset, readable_org_guids)
      end

      def fetch_all(message:)
        dataset = QuotaDefinition.dataset
        filter(message, dataset, nil)
      end

      private

      def filter(message, dataset, readable_org_guids)
        if message.requested? :names
          dataset = dataset.where(name: message.names)
        end

        if message.requested? :organization_guids
          if readable_org_guids
            guids = message.organization_guids & readable_org_guids
          else
            guids = message.organization_guids
          end

          dataset = dataset.
                    join(:organizations, quota_definition_id: :id).
                    where(Sequel[:organizations][:guid] => guids).distinct.
                    qualify(:quota_definitions)
        end

        super(message, dataset, QuotaDefinition)
      end
    end
  end
end
