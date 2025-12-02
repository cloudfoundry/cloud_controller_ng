module Fog
  module Google
    class StorageXML
      class Mock
        include Utils

        def self.acls(type)
          case type
          when "private"
            {
              "AccessControlList" => [
                {
                  "Permission" => "FULL_CONTROL",
                  "Scope" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0", "type" => "UserById" }
                }
              ],
              "Owner" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0" }
            }
          when "public-read"
            {
              "AccessControlList" => [
                {
                  "Permission" => "FULL_CONTROL",
                  "Scope" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0", "type" => "UserById" }
                },
                {
                  "Permission" => "READ",
                  "Scope" => { "type" => "AllUsers" }
                }
              ],
              "Owner" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0" }
            }
          when "public-read-write"
            {
              "AccessControlList" => [
                {
                  "Permission" => "FULL_CONTROL",
                  "Scope" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0", "type" => "UserById" }
                },
                {
                  "Permission" => "READ",
                  "Scope" => { "type" => "AllUsers" }
                },
                {
                  "Permission" => "WRITE",
                  "Scope" => { "type" => "AllUsers" }
                }
              ],
              "Owner" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0" }
            }
          when "authenticated-read"
            {
              "AccessControlList" => [
                {
                  "Permission" => "FULL_CONTROL",
                  "Scope" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0", "type" => "UserById" }
                },
                {
                  "Permission" => "READ",
                  "Scope" => { "type" => "AllAuthenticatedUsers" }
                }
              ],
              "Owner" => { "ID" => "2744ccd10c7533bd736ad890f9dd5cab2adb27b07d500b9493f29cdc420cb2e0" }
            }
          end
        end

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :acls => {
                :bucket => {},
                :object => {}
              },
              :buckets => {}
            }
          end
        end

        def self.reset
          @data = nil
        end

        def initialize(options = {})
          @google_storage_access_key_id = options[:google_storage_access_key_id]
        end

        def data
          self.class.data[@google_storage_access_key_id]
        end

        def reset_data
          self.class.data.delete(@google_storage_access_key_id)
        end

        def signature(_params)
          "foo"
        end
      end
    end
  end
end
