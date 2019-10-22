module VCAP::CloudController
  module Jobs
    class LocalQueue < Struct.new(:config)
      def to_s
        "cc-#{config.get(:name)}-#{config.get(:index)}"
      end
    end
  end
end
