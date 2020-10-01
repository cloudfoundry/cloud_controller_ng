require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class OrgListFetcher < BaseListFetcher
    class << self
      def fetch(message:, guids:, eager_loaded_associations: [])
        dataset = Organization.where(guid: guids)
        dataset = eager_load(dataset, eager_loaded_associations)
        filter(message, dataset)
      end

      def fetch_all(message:, eager_loaded_associations: [])
        dataset = Organization.dataset
        dataset = eager_load(dataset, eager_loaded_associations)
        filter(message, dataset)
      end

      def fetch_for_isolation_segment(message:, guids:, eager_loaded_associations: [])
        isolation_segment = IsolationSegmentModel.where(guid: message.isolation_segment_guid).first
        return nil unless isolation_segment

        dataset = isolation_segment.organizations_dataset.where(guid: guids)
        dataset = eager_load(dataset, eager_loaded_associations)
        [isolation_segment, filter(message, dataset)]
      end

      def fetch_all_for_isolation_segment(message:, eager_loaded_associations: [])
        isolation_segment = IsolationSegmentModel.where(guid: message.isolation_segment_guid).first
        return nil unless isolation_segment

        dataset = isolation_segment.organizations_dataset
        dataset = eager_load(dataset, eager_loaded_associations)
        [isolation_segment, filter(message, dataset)]
      end

      private

      def eager_load(dataset, associated_resources=[])
        return dataset if associated_resources.empty?

        dataset.eager(*associated_resources)
      end

      def filter(message, dataset)
        if message.requested?(:names)
          dataset = dataset.where(name: message.names)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: OrganizationLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: Organization,
          )
        end

        super(message, dataset, Organization)
      end
    end
  end
end
