require "find"

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
      dir.files
    end

    def cp_r_from_local(local_dir_path)
      Find.find(local_dir_path).each do |local_file_path|
        next unless File.file?(local_file_path)

        sha1 = Digest::SHA1.file(local_file_path).hexdigest
        key = key_from_sha1(sha1)
        next if files.head(key)

        File.open(local_file_path) do |file|
          files.create(
            :key    => key,
            :body   => file,
            :public => false,
          )
        end
      end
    end

    private

    def dir
      @dir ||= connection.directories.create(:key => @directory_key, :public => false)
    end

    def connection
      options = @connection_config
      options = options.merge(:endpoint => "") if local?
      Fog::Storage.new(options)
    end

    def key_from_sha1(sha1)
      sha1 = sha1.to_s.downcase
      File.join(sha1[0..1], sha1[2..3], sha1)
    end
  end
end
