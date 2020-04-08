require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class OrganizationQuotaListFetcher
    class << self
      def fetch(message:, readable_org_guids:)
        dataset = QuotaDefinition.dataset
        filter(message, dataset, readable_org_guids)
      end

      private

      def filter(message, dataset, readable_org_guids)
        if message.requested? :names
          dataset = dataset.where(name: message.names)
        end

        if message.requested? :guids
          dataset = dataset.where(guid: message.guids)
        end

        if message.requested? :organization_guids
          dataset = dataset.
                    join(:organizations, quota_definition_id: :id).
                    where(Sequel[:organizations][:guid] => message.organization_guids & readable_org_guids).distinct.
                    qualify(:quota_definitions)
        end

        dataset
      end
    end
  end
end
