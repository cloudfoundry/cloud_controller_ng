require 'presenters/system_env_presenter'

module VCAP::CloudController
  module Diego
    class NormalEnvHashToDiegoEnvArrayPhilosopher
      def self.muse(hash)
        hash.map do |k, v|
          case v
          when Array, Hash
            v = MultiJson.dump(v)
          else
            v = v.to_s
          end

          { 'name' => k.to_s, 'value' => v }
        end
      end
    end
  end
end
