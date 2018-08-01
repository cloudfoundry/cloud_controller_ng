module CloudController
  module Presenters
    module V2
      class AppUsageEventPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::AppUsageEvent'

        def entity_hash(controller, app_usage_event, opts, depth, parents, orphans=nil)
          entity = {
            'state'                              => app_usage_event.state,
            'previous_state'                     => app_usage_event.previous_state,
            'memory_in_mb_per_instance'          => app_usage_event.memory_in_mb_per_instance,
            'previous_memory_in_mb_per_instance' => app_usage_event.previous_memory_in_mb_per_instance,
            'instance_count'                     => app_usage_event.instance_count,
            'previous_instance_count'            => app_usage_event.previous_instance_count,
            'app_guid'                           => app_usage_event.app_guid,
            'app_name'                           => app_usage_event.app_name,
            'space_guid'                         => app_usage_event.space_guid,
            'space_name'                         => app_usage_event.space_name,
            'org_guid'                           => app_usage_event.org_guid,
            'buildpack_guid'                     => app_usage_event.buildpack_guid,
            'buildpack_name'                     => obfuscated_buildpack_name(app_usage_event.buildpack_name),
            'package_state'                      => app_usage_event.package_state,
            'previous_package_state'             => app_usage_event.previous_package_state,
            'parent_app_guid'                    => app_usage_event.parent_app_guid,
            'parent_app_name'                    => app_usage_event.parent_app_name,
            'process_type'                       => app_usage_event.process_type,
            'task_name'                          => app_usage_event.task_name,
            'task_guid'                          => app_usage_event.task_guid
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, app_usage_event, opts, depth, parents, orphans))
        end

        private

        def obfuscated_buildpack_name(buildpack_name)
          CloudController::UrlSecretObfuscator.obfuscate(buildpack_name)
        end
      end
    end
  end
end
