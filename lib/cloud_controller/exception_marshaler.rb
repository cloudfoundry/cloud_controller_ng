module VCAP::CloudController
  module ExceptionMarshaler
    def self.marshal(exception)
      YAML.dump(exception)
    end

    def self.unmarshal(yaml)
      YAML.load(yaml)
    end
  end
end