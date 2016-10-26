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

      dataset
    end
  end
end
