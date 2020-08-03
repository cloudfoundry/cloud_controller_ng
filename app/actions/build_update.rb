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
          droplet = build.droplet
          droplet.lock!
          droplet.docker_receipt_image = message.lifecycle.dig(:data, :image)
          droplet.process_types = message.lifecycle.dig(:data, :processTypes)
          droplet.mark_as_staged
          droplet.save_changes
          build.mark_as_staged
          build.save_changes

          app = build.app
          app.update(droplet: droplet)
        end
      end

      @logger.info("Finished updating metadata on build #{build.guid}")
      build
    rescue Sequel::ValidationFailed => e
      raise InvalidBuild.new(e.message)
    end
  end
end
