require 'presenters/system_environment/system_env_presenter'

module VCAP::CloudController
  module Diego
    class NormalEnvHashToDiegoEnvArrayPhilosopher
      def self.muse(hash)
        hash.map do |k, v|
          v = case v
              when Array, Hash
                MultiJson.dump(v)
              else
                v.to_s
              end

          { 'name' => k.to_s, 'value' => v }
        end
      end
    end
  end
end
