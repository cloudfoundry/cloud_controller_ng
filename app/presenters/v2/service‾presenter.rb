module CloudController
  module Presenters
    module V2
      class ServicePresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::Service'

        def entity_hash(controller, service, opts, depth, parents, orphans=nil)
          rel_hash = RelationsPresenter.new.to_hash(controller, service, opts, depth, parents, orphans)

          {
            'label'                 => service.label,
            'provider'              => service.provider,
            'url'                   => service.url,
            'description'           => service.description,
            'long_description'      => service.long_description,
            'version'               => service.version,
            'info_url'              => service.info_url,
            'active'                => service.active,
            'bindable'              => service.bindable,
            'unique_id'             => service.unique_id,
            'extra'                 => service.extra,
            'tags'                  => service.tags,
            'requires'              => service.requires,
            'documentation_url'     => service.documentation_url,
            'service_broker_guid'   => service&.service_broker&.guid,
            'service_broker_name'   => service&.service_broker&.name,
            'plan_updateable'       => service.plan_updateable,
            'bindings_retrievable'  => service.bindings_retrievable,
            'instances_retrievable' => service.instances_retrievable,
            'allow_context_updates' => service.allow_context_updates
          }.merge!(rel_hash)
        end
      end
    end
  end
end
