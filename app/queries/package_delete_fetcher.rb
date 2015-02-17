module VCAP::CloudController
  class PackageDeleteFetcher
    def initialize(user)
      @user = user
    end

    def fetch(package_guid)
      dataset.where(:"#{PackageModel.table_name}__guid" => package_guid).first
    end

    private

    def dataset
      ds = PackageModel.dataset
      return ds if @user.admin?

      ds.select_all(PackageModel.table_name).
        join(:spaces, guid: :space_guid).where(space_guid: @user.spaces_dataset.select(:guid)).
        join(:organizations, id: :spaces__organization_id).where(organizations__status: 'active')
    end
  end
end
