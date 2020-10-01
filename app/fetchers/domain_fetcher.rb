require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class DomainFetcher < BaseListFetcher
    class << self
      def fetch_all_for_orgs(readable_org_guids)
        # Q: The "Domain" in Domain.dataset is arbitrary -- just a way to get access to any database table.
        # If there's a way to use a more generic way to access the database, maybe this can be revised.
        #
        readable_orgs_filter = Domain.dataset.db[:organizations].where(guid: readable_org_guids).select(:id)

        readable_shared_private_domains_filter = Domain.dataset.db[:organizations_private_domains].where(
          organization_id: readable_orgs_filter
        ).select(:private_domain_id)

        user_visible_domains = Sequel.or([
          Domain::SHARED_DOMAIN_CONDITION.flatten,
          [:owning_organization_id, readable_orgs_filter],
          [:id, readable_shared_private_domains_filter]
        ]).sql_boolean

        Domain.where(user_visible_domains).qualify
      end

      def fetch(message, readable_org_guids)
        dataset = fetch_all_for_orgs(readable_org_guids)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:guid)
          dataset = dataset.where(guid: message.guid)
        end

        if message.requested?(:names)
          dataset = dataset.where(name: message.names)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.where(owning_organization_id: Organization.where(guid: message.organization_guids).select(:id))
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: DomainLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Domain,
          )
        end

        super(message, dataset, Domain)
      end
    end
  end
end
