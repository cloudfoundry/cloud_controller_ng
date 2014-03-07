module VCAP::CloudController
  class UploadBuildpack
    attr_reader :buildpack_blobstore

    def initialize(blobstore)
      @buildpack_blobstore = blobstore
    end

    def upload_bits(buildpack, bits_file, new_filename)
      return false if buildpack.locked

      sha1 = File.new(bits_file).hexdigest
      new_key = "#{buildpack.guid}_#{sha1}"

      return false if !new_bits?(buildpack, new_key) && !new_filename?(buildpack, new_filename)

      # replace blob if new
      if new_bits?(buildpack, new_key)
        buildpack_blobstore.cp_to_blobstore(bits_file, new_key)
        old_buildpack_key = buildpack.key
      end

      Buildpack.db.transaction(savepoint: true) do
        buildpack.lock!
        buildpack.update_from_hash(key: new_key, filename: new_filename)
      end

      staging_timeout = VCAP::CloudController::Config.config[:staging][:timeout_in_seconds]
      BuildpackBitsDelete.delete_when_safe(old_buildpack_key, :buildpack_blobstore, staging_timeout)
      return true
    end

    def new_bits?(buildpack, key)
      return buildpack.key != key
    end

    def new_filename?(buildpack, filename)
      return buildpack.filename != filename
    end

  end
end
