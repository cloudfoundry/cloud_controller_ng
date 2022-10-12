require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class IsolationSegmentListFetcher < BaseListFetcher
    class << self
      def fetch_all(message)
        dataset = IsolationSegmentModel.dataset
        filter(message, dataset)
      end

      def fetch_for_organizations(message, org_guids_query:)
        dataset = IsolationSegmentModel.dataset.where(organizations: org_guids_query)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:guids)
          dataset = dataset.where("#{IsolationSegmentModel.table_name}__guid".to_sym => message.guids)
        end

        if message.requested?(:names)
          dataset = dataset.where("#{IsolationSegmentModel.table_name}__name".to_sym => message.names)
        end

        if message.requested?(:organization_guids)
          dataset = dataset.join(:organizations_isolation_segments, {
            Sequel[:isolation_segments][:guid] => Sequel[:organizations_isolation_segments][:isolation_segment_guid]
          }).where(Sequel.qualify(:organizations_isolation_segments, :organization_guid) => message.organization_guids)
        end

        if message.requested?(:label_selector)
          dataset = LabelSelectorQueryGenerator.add_selector_queries(
            label_klass: IsolationSegmentLabelModel,
            resource_dataset: dataset,
            requirements: message.requirements,
            resource_klass: IsolationSegmentModel,
          )
        end

        super(message, dataset, IsolationSegmentModel)
      end
    end
  end
end
