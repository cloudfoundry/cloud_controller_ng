module VCAP::CloudController
  class BitsExpiration
    def initialize(input_config=Config.config)
      config                  = {}
      config[:packages]       = input_config[:packages] || {}
      config[:droplets]       = input_config[:droplets] || {}
      @packages_storage_count = config[:packages][:max_valid_packages_stored] || 5
      @droplets_storage_count = config[:droplets][:max_staged_droplets_stored] || 5
    end

    attr_reader :droplets_storage_count, :packages_storage_count

    def expire_droplets!(app)
      expirable_candidates = DropletModel.
                             where(state: DropletModel::STAGED_STATE, app_guid: app.guid).
                             exclude(guid: app.droplet_guid)

      return if expirable_candidates.count < droplets_storage_count

      droplets_to_expire = filter_non_expirable(expirable_candidates, droplets_storage_count)

      droplets_to_expire.all.each do |droplet|
        droplet.update(state: DropletModel::EXPIRED_STATE)
        enqueue_droplet_delete_job(droplet.guid)
      end
    end

    def expire_packages!(app)
      current_package_guid = app.droplet.try(:package_guid)

      expirable_candidates = PackageModel.
                             where(state: PackageModel::READY_STATE, app_guid: app.guid).
                             exclude(guid: current_package_guid)

      return if expirable_candidates.count < packages_storage_count

      packages_to_expire = filter_non_expirable(expirable_candidates, packages_storage_count)

      packages_to_expire.all.each do |package|
        package.update(state: PackageModel::EXPIRED_STATE)
        enqueue_package_delete_job(package.guid)
      end
    end

    private

    def enqueue_droplet_delete_job(droplet_guid)
      Jobs::Enqueuer.new(
        Jobs::Runtime::DeleteExpiredDropletBlob.new(droplet_guid),
        queue: 'cc-generic'
      ).enqueue
    end

    def enqueue_package_delete_job(package_guid)
      Jobs::Enqueuer.new(
        Jobs::Runtime::DeleteExpiredPackageBlob.new(package_guid),
        queue: 'cc-generic'
      ).enqueue
    end

    def filter_non_expirable(dataset, storage_count)
      data_to_keep = dataset.order_by(Sequel.desc(:created_at)).limit(storage_count).select(:id)
      dataset.exclude(id: data_to_keep)
    end
  end
end
