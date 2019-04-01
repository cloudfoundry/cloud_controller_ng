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
        options = { max_keys: 1 }
        options['limit'] = 1 if @connection.service == Fog::Storage::OpenStack
        @connection.directories.get(@key, options)
      end
    end
  end
end
