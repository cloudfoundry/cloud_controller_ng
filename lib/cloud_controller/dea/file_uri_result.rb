module VCAP::CloudController
  module Dea
    class FileUriResult < Struct.new(:file_uri_v1, :file_uri_v2, :credentials)
      def initialize(opts={})
        if opts[:file_uri_v2]
          self.file_uri_v2 = opts[:file_uri_v2]
        end
        if opts[:file_uri_v1]
          self.file_uri_v1 = opts[:file_uri_v1]
        end
        if opts[:credentials]
          self.credentials = opts[:credentials]
        end
      end
    end
  end
end
