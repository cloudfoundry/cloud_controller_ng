require 'presenters/system_environment/system_env_presenter'

module OPI
  class EnvHash
    def self.muse(hash)
      return [] if hash.nil?

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
