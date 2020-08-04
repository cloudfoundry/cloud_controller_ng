require 'cloud_controller/yaml_config'

module VCAP::CloudController
  class SecretsFetcher
    class << self
      def fetch_secrets_from_file(secrets_file)
        secrets_refs = YAMLConfig.safe_load_file(secrets_file)

        traverse_secrets_hash(secrets_refs)
      end

      private

      def traverse_secrets_hash(secrets_hash)
        secrets_hash.each { |k, v|
          if v.is_a? Hash
            traverse_secrets_hash(v)
          else
            raise "unable to read secret value file: #{v.inspect}" unless File.exist?(v)

            secret_value = File.read(v)
            secrets_hash[k] = secret_value
          end
        }
      end
    end
  end
end
