require 'vcap/digester'

module VCAP::CloudController
  class UploadBuildpack
    attr_reader :buildpack_blobstore
    ONE_MEGABYTE = 1024 * 1024

    def initialize(blobstore)
      @buildpack_blobstore = blobstore
    end

    def upload_buildpack(buildpack, bits_file_path, new_filename)
      return false if buildpack.locked

      sha256 = Digester.new(algorithm: Digest::SHA256).digest_path(bits_file_path)
      new_key = "#{buildpack.guid}_#{sha256}"
      missing_bits = buildpack.key && !buildpack_blobstore.exists?(buildpack.key)

      return false if !new_bits?(buildpack, new_key) && !new_filename?(buildpack, new_filename) && !missing_bits

      # replace blob if new
      if missing_bits || new_bits?(buildpack, new_key)
        buildpack_blobstore.cp_to_blobstore(bits_file_path, new_key)
      end

      old_buildpack_key = nil

      new_stack = determine_new_stack(buildpack, bits_file_path)

      begin
        Buildpack.db.transaction do
          buildpack.lock!
          old_buildpack_key = buildpack.key
          buildpack.update(
            key: new_key,
            filename: new_filename,
            sha256_checksum: sha256,
            stack: new_stack
          )
        end
      rescue Sequel::ValidationFailed
        raise_translated_api_error(buildpack)
      rescue Sequel::Error
        BuildpackBitsDelete.delete_when_safe(new_key, 0)
        return false
      end

      if !missing_bits && old_buildpack_key && new_bits?(buildpack, old_buildpack_key)
        staging_timeout = VCAP::CloudController::Config.config.get(:staging, :timeout_in_seconds)
        BuildpackBitsDelete.delete_when_safe(old_buildpack_key, staging_timeout)
      end

      true
    end

    private

    def raise_translated_api_error(buildpack)
      if buildpack.errors.on([:name, :stack]).try(:include?, :unique)
        raise CloudController::Errors::ApiError.new_from_details('BuildpackNameStackTaken', buildpack.name, buildpack.stack)
      end
      if buildpack.errors.on(:stack).try(:include?, :buildpack_cant_change_stacks)
        raise CloudController::Errors::ApiError.new_from_details('BuildpackStacksDontMatch', buildpack.stack, buildpack.initial_value(:stack))
      end
      if buildpack.errors.on(:stack).try(:include?, :buildpack_stack_does_not_exist)
        raise CloudController::Errors::ApiError.new_from_details('BuildpackStackDoesNotExist', buildpack.stack)
      end
    end

    def determine_new_stack(buildpack, bits_file_path)
      extracted_stack = Buildpacks::StackNameExtractor.extract_from_file(bits_file_path)
      [extracted_stack, buildpack.stack, Stack.default.name].find(&:present?)
    rescue CloudController::Errors::BuildpackError => e
      raise CloudController::Errors::ApiError.new_from_details('BuildpackZipError', e.message)
    end

    def new_bits?(buildpack, key)
      buildpack.key != key
    end

    def new_filename?(buildpack, filename)
      buildpack.filename != filename
    end
  end
end
