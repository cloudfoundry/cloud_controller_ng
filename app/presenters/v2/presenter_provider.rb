module CloudController
  module Presenters
    module V2
      module PresenterProvider
        def self.presenter_for(obj)
          presenters.fetch(obj.class.name, DefaultPresenter).new
        end

        def present_for_class(klass)
          PresenterProvider.presenters[klass] = self
        end

        def self.presenters
          @presenters ||= {}
        end
      end
    end
  end
end

require_relative 'base_presenter'
require_relative 'default_presenter'
require_relative 'relations_presenter'

require_relative 'private_domain_presenter'
require_relative 'app_presenter'
require_relative 'app_usage_event_presenter'
require_relative 'route_presenter'
require_relative 'shared_domain_presenter'
require_relative 'route_mapping_presenter'
require_relative 'service_binding_presenter'
require_relative 'service_instance_presenter'
require_relative 'space_presenter'
require_relative 'organization_presenter'
