module VCAP::CloudController
  class PackageDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(package_guid)
      dataset.where(:"#{PackageModel.table_name}__guid" => package_guid)
    end

    private

    def dataset
      ds = PackageModel.dataset
      return ds if @user.admin?

      ds.association_join(:space).
        where(space__guid: @user.spaces_dataset.association_join(:organization).
              where(organization__status: 'active').select(:space__guid)).
        select_all(PackageModel.table_name)
    end
  end
end
