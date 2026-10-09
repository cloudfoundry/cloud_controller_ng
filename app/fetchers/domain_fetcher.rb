require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class DomainFetcher < BaseListFetcher
    class << self
      def fetch_all_for_orgs(readable_org_ids)
        shared_domain_ids = Domain.where(owning_organization_id: nil).select(:id)
        owned_domain_ids  = Domain.where(owning_organization_id: readable_org_ids).select(:id)
        shared_private_domain_ids = Domain.dataset.db[:organizations_private_domains].where(
          organization_id: readable_org_ids
        ).select(Sequel[:private_domain_id].as(:id))

        all_domain_ids = shared_domain_ids.
                         union(owned_domain_ids, all: true, from_self: false).
                         union(shared_private_domain_ids, all: true, from_self: false)

        Domain.where(id: all_domain_ids).qualify
      end

      def fetch(message, readable_org_ids)
        dataset = fetch_all_for_orgs(readable_org_ids)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        dataset = dataset.where(guid: message.guid) if message.requested?(:guid)

        dataset = dataset.where(name: message.names) if message.requested?(:names)

        dataset = dataset.where(owning_organization_id: Organization.where(guid: message.organization_guids).select(:id)) if message.requested?(:organization_guids)

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: DomainLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Domain
          )
        end

        super(message, dataset, Domain)
      end
    end
  end
end
