module Fog
  module Google
    class StorageXML
      class Directory < Fog::Model
        identity :key, :aliases => %w(Name name)

        attribute :creation_date, :aliases => "CreationDate"

        def acl=(new_acl)
          unless Utils::VALID_ACLS.include?(new_acl)
            raise ArgumentError.new("acl must be one of [#{Utils::VALID_ACLS.join(', ')}]")
          end
          @acl = new_acl
        end

        def destroy
          requires :key
          service.delete_bucket(key)
          true
        rescue Excon::Errors::NotFound
          false
        end

        def files
          @files ||= begin
            Fog::Google::StorageXML::Files.new(
              :directory => self,
              :service => service
            )
          end
        end

        def public=(new_public)
          if new_public
            @acl = "public-read"
          else
            @acl = "private"
          end
          new_public
        end

        def public_url
          requires :key
          if service.get_bucket_acl(key).body["AccessControlList"].detect { |entry| entry["Scope"]["type"] == "AllUsers" && entry["Permission"] == "READ" }
            if key.to_s =~ /^(?:[a-z]|\d(?!\d{0,2}(?:\.\d{1,3}){3}$))(?:[a-z0-9]|\.(?![\.\-])|\-(?![\.])){1,61}[a-z0-9]$/
              "https://#{key}.storage.googleapis.com"
            else
              "https://storage.googleapis.com/#{key}"
            end
          end
        end

        def save
          requires :key
          options = {}
          options["x-goog-acl"] = @acl if @acl
          options["LocationConstraint"] = @location if @location
          options["StorageClass"] = attributes[:storage_class] if attributes[:storage_class]
          service.put_bucket(key, options)
          true
        end
      end
    end
  end
end
