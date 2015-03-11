module VCAP::CloudController
  class PackageDelete
    def initialize(package_dataset)
      @package_dataset = package_dataset
    end

    def delete
      package_dataset.select(:"#{PackageModel.table_name}__guid").each do |package|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(package.guid, :package_blobstore, nil)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
      end
      package_dataset.destroy
    end

    private

    attr_reader :package_dataset
  end
end
