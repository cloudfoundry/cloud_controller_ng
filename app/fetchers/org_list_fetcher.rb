require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class OrgListFetcher
    def fetch(message:, guids:)
      dataset = Organization.where(guid: guids)
      filter(message, dataset)
    end

    def fetch_all(message:)
      dataset = Organization.dataset
      filter(message, dataset)
    end

    def fetch_for_isolation_segment(message:, guids:)
      isolation_segment = IsolationSegmentModel.where(guid: message.isolation_segment_guid).all.first
      return nil unless isolation_segment

      dataset = isolation_segment.organizations_dataset.where(guid: guids)
      [isolation_segment, filter(message, dataset)]
    end

    def fetch_all_for_isolation_segment(message:)
      isolation_segment = IsolationSegmentModel.where(guid: message.isolation_segment_guid).all.first
      return nil unless isolation_segment

      dataset = isolation_segment.organizations_dataset
      [isolation_segment, filter(message, dataset)]
    end

    private

    def filter(message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      if message.requested?(:guids)
        dataset = dataset.where(guid: message.guids)
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: OrganizationLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: Organization,
        )
      end

      dataset
    end
  end
end
