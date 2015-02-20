module VCAP::CloudController
  class DropletDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(droplet_guid)
      dataset.where(:"#{DropletModel.table_name}__guid" => droplet_guid)
    end

    private

    def dataset
      ds = DropletModel.dataset
      return ds if @user.admin?

      ds.association_join(:space).
        where(space__guid: @user.spaces_dataset.association_join(:organization).
              where(organization__status: 'active').select(:space__guid)).
        select_all(DropletModel.table_name)
    end
  end
end
