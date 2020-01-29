module VCAP::CloudController
  class BuildUpdate
    class InvalidBuild < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.build_update')
    end

    def update(build, message)
      build.db.transaction do
        build.lock!
        MetadataUpdate.update(build, message)

        if message.state == VCAP::CloudController::BuildModel::FAILED_STATE
          build.fail_to_stage!('StagerError', message.error)
        elsif message.state == VCAP::CloudController::BuildModel::STAGED_STATE
          droplet = VCAP::CloudController::DropletCreate.new.create_docker_droplet(build)
          droplet.lock!
          droplet.update(docker_receipt_image: message.lifecycle.dig(:data, :image))

          build.mark_as_staged
          build.save_changes
        end
      end

      @logger.info("Finished updating metadata on build #{build.guid}")
      build
    rescue Sequel::ValidationFailed => e
      raise InvalidBuild.new(e.message)
    end
  end
end
