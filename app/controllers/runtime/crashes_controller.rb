require 'controllers/runtime/mixins/find_process_through_app'

module VCAP::CloudController
  class CrashesController < RestController::ModelController
    include FindProcessThroughApp

    def self.dependencies
      [:instances_reporters]
    end

    path_base 'apps'
    model_class_name :ProcessModel
    self.not_found_exception_name = 'AppNotFound'

    get "#{path_guid}/crashes", :crashes

    def crashes(guid)
      process           = find_guid_and_validate_access(:read, guid)
      crashed_instances = instances_reporters.crashed_instances_for_app(process)
      Oj.dump(crashed_instances, mode: :compat)
    end

    protected

    attr_reader :instances_reporters

    def inject_dependencies(dependencies)
      super
      @instances_reporters = dependencies[:instances_reporters]
    end
  end
end
