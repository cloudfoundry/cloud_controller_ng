module VCAP::CloudController
  class PackageStageFetcher
    def initialize(user)
      @user = user
    end

    def fetch(package_guid, buildpack_guid)
      package = dataset.where(:"#{PackageModel.table_name}__guid" => package_guid).first

      return nil if package.nil?

      buildpack = Buildpack.find(guid: buildpack_guid)

      [package, package.app, package.space, buildpack]
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
