class BlobstoreDelete < Struct.new(:key, :blobstore_name)
  def perform
    blobstore = CloudController::DependencyLocator.instance.public_send(blobstore_name)
    blobstore.delete(key)
  end
end