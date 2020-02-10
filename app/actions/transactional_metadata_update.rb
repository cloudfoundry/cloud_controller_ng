module VCAP::CloudController
  class TransactionalMetadataUpdate
    class << self
      def update(resource, message)
        resource.db.transaction do
          MetadataUpdate.update(resource, message)
        end

        resource
      end
    end
  end
end
