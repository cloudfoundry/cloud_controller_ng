module VCAP::CloudController
  class IsolationSegmentListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_all
      dataset = IsolationSegmentModel.dataset
      filter(dataset)
    end

    def fetch_for_organizations(org_guids:)
      dataset = IsolationSegmentModel.dataset.where(organizations: Organization.where(guid: org_guids))
      filter(dataset)
    end

    private

    def filter(dataset)
      if @message.requested?(:guids)
        dataset = dataset.where("#{IsolationSegmentModel.table_name}__guid".to_sym => @message.guids)
      end

      if @message.requested?(:names)
        dataset = dataset.where("#{IsolationSegmentModel.table_name}__name".to_sym => @message.names)
      end

      if @message.requested?(:organization_guids)
        dataset = dataset.join(:organizations_isolation_segments, {
          Sequel[:isolation_segments][:guid] => Sequel[:organizations_isolation_segments][:isolation_segment_guid]
        }).where(Sequel.qualify(:organizations_isolation_segments, :organization_guid) => @message.organization_guids)
      end

      if @message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: IsolationSegmentLabelModel,
          resource_dataset: dataset,
          requirements: @message.requirements,
          resource_klass: IsolationSegmentModel,
        )
      end

      dataset
    end
  end
end
