module VCAP::CloudController
  class BlobStore
    def initialize(connection_config, directory_key)
      @connection_config = connection_config
      @directory_key = directory_key
    end

    def local?
      @connection_config[:provider].downcase == "local"
    end

    def files
      directory.files
    end

    private

    def directory
      @directory ||= connection.directories.create(:key => @directory_key, :public => false)
    end

    def connection
      options = @connection_config
      options = options.merge(:endpoint => "") if local?
      Fog::Storage.new(options)
    end
  end
end
