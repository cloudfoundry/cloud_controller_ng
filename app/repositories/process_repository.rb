require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  class ProcessRepository
    class MutationAttempWithoutALock < StandardError; end
    class InvalidProcess < StandardError; end
    class ProcessNotFound < StandardError; end

    def new_process(opts)
      AppProcess.new(opts)
    end

    def persist!(desired_process)
      process_model = if desired_process.guid
                        raise MutationAttempWithoutALock unless @lock_acquired
                        changes = changes_for_process(desired_process)
                        App.first!(guid: desired_process.guid).update(changes)
                      else
                        attributes = attributes_for_process(desired_process).reject { |_, v| v.nil? }
                        App.create(attributes)
                      end

      ProcessMapper.map_model_to_domain(process_model)
    rescue Sequel::ValidationFailed => e
      raise InvalidProcess.new(e.message)
    rescue Sequel::NoMatchingRow => e
      raise ProcessNotFound.new(e.message)
    end

    def find_by_guid(guid)
      process_model = App.find(guid: guid)
      return if process_model.nil?
      ProcessMapper.map_model_to_domain(process_model)
    end

    def find_by_guid_for_update(guid)
      process_model = App.find(guid: guid)
      yield nil and return if process_model.nil?

      process_model.db.transaction do
        process_model.lock!
        process = ProcessMapper.map_model_to_domain(process_model)
        @lock_acquired = true
        begin
          yield process
        ensure
          @lock_acquired = false
        end
      end
    end

    def update(process, changes)
      old_changes = process.changes
      attributes = attributes_for_process(process).merge(changes)

      AppProcess.new(attributes, old_changes.merge(changes))
    end

    def delete(process)
      process_model = App.find(guid: process.guid)
      return unless process_model
      raise MutationAttempWithoutALock unless @lock_acquired
      process_model.destroy
    end

    private

    def changes_for_process(process)
      process.changes
    end

    def attributes_for_process(process)
      {
        guid:                 process.guid,
        name:                 process.name,
        space_guid:           process.space_guid,
        stack_guid:           process.stack_guid,
        disk_quota:           process.disk_quota,
        memory:               process.memory,
        instances:            process.instances,
        state:                process.state,
        command:              process.command,
        buildpack:            process.buildpack,
        health_check_timeout: process.health_check_timeout,
        docker_image:         process.docker_image,
        environment_json:     process.environment_json
      }
    end

    def get_command_from_model(model)
      metadata = MultiJson.load(model.values[:metadata])
      return nil unless metadata
      return metadata['command']
    end
  end
end
