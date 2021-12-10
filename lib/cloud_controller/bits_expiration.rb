module VCAP::CloudController
  class BitsExpiration
    def initialize(config=Config.config)
      packages = config.get(:packages)
      droplets = config.get(:droplets)
      @packages_storage_count = packages[:max_valid_packages_stored]
      @droplets_storage_count = droplets[:max_staged_droplets_stored]
    end

    attr_reader :droplets_storage_count, :packages_storage_count

    def expire_droplets!(app)
      expirable_candidates = DropletModel.
                             where(state: DropletModel::STAGED_STATE, app_guid: app.guid).
                             exclude(guid: app.droplet_guid)

      return if expirable_candidates.count < droplets_storage_count

      droplets_to_expire = filter_non_expirable(expirable_candidates, droplets_storage_count)

      droplets_to_expire.each do |droplet|
        droplet.update(state: DropletModel::EXPIRED_STATE)
        enqueue_droplet_delete_job(droplet.guid) if droplet.droplet_hash
      end
    end

    def expire_packages!(app)
      current_package_guid = app.droplet.try(:package_guid)

      expirable_candidates = PackageModel.
                             where(state: PackageModel::READY_STATE, app_guid: app.guid).
                             exclude(guid: current_package_guid)

      return if expirable_candidates.count < packages_storage_count

      packages_to_expire = filter_non_expirable(expirable_candidates, packages_storage_count)

      packages_to_expire.each do |package|
        package.update(state: PackageModel::EXPIRED_STATE)
        enqueue_package_delete_job(package.guid)
      end
    end

    private

    def enqueue_droplet_delete_job(droplet_guid)
      Jobs::Enqueuer.new(
        Jobs::Runtime::DeleteExpiredDropletBlob.new(droplet_guid),
        queue: Jobs::Queues.generic
      ).enqueue
    end

    def enqueue_package_delete_job(package_guid)
      Jobs::Enqueuer.new(
        Jobs::Runtime::DeleteExpiredPackageBlob.new(package_guid),
        queue: Jobs::Queues.generic
      ).enqueue
    end

    def filter_non_expirable(dataset, storage_count)
      data_to_keep = dataset.order_by(Sequel.desc(:created_at)).limit(storage_count).select(:id)
      dataset.exclude(id: data_to_keep)
    end
  end
end
