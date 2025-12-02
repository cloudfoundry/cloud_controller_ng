module Fog
  module Google
    class StorageJSON
      ##
      # Represents a Google Storage bucket
      class Directory < Fog::Model
        identity :key, :aliases => ["Name", "name", :name]

        attribute :acl
        attribute :billing
        attribute :cors
        attribute :default_object_acl, aliases => "defaultObjectAcl"
        attribute :etag
        attribute :id
        attribute :kind
        attribute :labels
        attribute :lifecycle
        attribute :location
        attribute :logging
        attribute :metageneration
        attribute :name
        attribute :owner
        attribute :project_number, aliases => "projectNumber"
        attribute :self_link, aliases => "selfLink"
        attribute :storage_class, aliases => "storageClass"
        attribute :time_created, aliases => "timeCreated"
        attribute :updated
        attribute :versioning
        attribute :website

        def destroy
          requires :key
          service.delete_bucket(key)
          true
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          false
        end

        def files(attr = {})
          @files ||= begin
            Fog::Google::StorageJSON::Files.new(
              attr.merge(:directory => self, :service => service)
            )
          end
        end

        def public_url
          requires :key
          "#{GOOGLE_STORAGE_BUCKET_BASE_URL}#{key}"
        end

        def save
          requires :key
          service.put_bucket(key, **attributes)
          true
        end
      end
    end
  end
end
