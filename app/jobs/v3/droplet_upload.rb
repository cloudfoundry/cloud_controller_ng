module VCAP::CloudController
  module Jobs
    module V3
      class DropletUpload
        attr_reader :max_attempts, :droplet_guid
        alias_method :resource_guid, :droplet_guid

        def initialize(local_path, droplet_guid, skip_state_transition:)
          @local_path   = local_path
          @droplet_guid = droplet_guid
          @skip_state_transition = skip_state_transition
          @max_attempts = 3
        end

        def perform
          droplet = DropletModel.find(guid: @droplet_guid)

          if droplet
            sha1_digest = Digester.new.digest_path(@local_path)
            sha256_digest = Digester.new(algorithm: OpenSSL::Digest::SHA256).digest_path(@local_path)

            blobstore.cp_to_blobstore(
              @local_path,
              File.join(@droplet_guid, sha1_digest)
            )

            droplet.mark_as_staged unless @skip_state_transition
            droplet.droplet_hash = sha1_digest
            droplet.sha256_checksum = sha256_digest
            droplet.save
          end

          FileUtils.rm_f(@local_path)
        rescue => e
          if droplet
            droplet.db.transaction do
              droplet.lock!
              droplet.error_description = e.message
              droplet.state = DropletModel::FAILED_STATE
              droplet.save
            end
          end
          raise
        end

        def error(job, _)
          if !File.exist?(@local_path)
            @max_attempts = 1
          end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(@local_path)
          end
        end

        def job_name_in_configuration
          :droplet_upload
        end

        def display_name
          'droplet.upload'
        end

        def resource_type
          'droplet'
        end

        def blobstore
          @blobstore ||= CloudController::DependencyLocator.instance.droplet_blobstore
        end
      end
    end
  end
end
