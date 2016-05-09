module VCAP::CloudController
  class DropletListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_all
      dataset = DropletModel.dataset
      filter(dataset)
    end

    def fetch_for_spaces(space_guids:)
      @space_guids = space_guids
      dataset = DropletModel.dataset
      filter(dataset)
    end

    def fetch_for_app
      app = AppModel.where(guid: @message.app_guid).eager(:space, space: :organization).all.first
      return nil unless app
      [app, filter(app.droplets_dataset)]
    end

    private

    def filter(dataset)
      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:states)
        dataset = dataset.where(state: @message.states)
      end

      if @message.requested?(:guids)
        dataset = dataset.where("#{DropletModel.table_name}__guid".to_sym => @message.guids)
      end

      if @message.requested?(:organization_guids)
        @space_guids ||= []
        @space_guids.concat(Organization.where(guid: @message.organization_guids).flat_map(&:spaces).map(&:guid))
      end

      if scoped_space_guids.present?
        dataset = dataset.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: scoped_space_guids)
      end

      dataset
    end

    def scoped_space_guids(permitted_space_guids: @space_guids, filtered_space_guids: @message.space_guids)
      return nil unless permitted_space_guids || filtered_space_guids
      return filtered_space_guids & permitted_space_guids if filtered_space_guids && permitted_space_guids
      return permitted_space_guids if permitted_space_guids
      return filtered_space_guids if filtered_space_guids
    end
  end
end
