module VCAP::CloudController
  class DropletDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(droplet_guid)
      dataset.where(:"#{DropletModel.table_name}__guid" => droplet_guid).first
    end

    private

    def dataset
      ds = DropletModel.dataset
      return ds if @user.admin?

      ds.select_all(DropletModel.table_name).
        join(AppModel.table_name, guid: :app_guid).
        join(Space.table_name, guid: :space_guid).where(space_guid: @user.spaces_dataset.select(:guid)).
        join(Organization.table_name, id: :organization_id).where(status: 'active')
    end
  end
end
