module VCAP::CloudController
  module Jobs
    class LocalQueue < Struct.new(:config)
      def to_s
        "cc-#{config[:name]}-#{config[:index]}"
      end
    end
  end
end
