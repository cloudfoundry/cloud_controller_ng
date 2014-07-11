module CloudController
  module Blobstore
    class Directory
      def initialize(connection, key)
        @connection = connection
        @key = key
      end

      def create
        @connection.directories.create(key: @key, public: false)
      end

      def get
        @connection.directories.get(@key, "limit" => 1, "max_keys" => 1)
      end
    end
  end
end
