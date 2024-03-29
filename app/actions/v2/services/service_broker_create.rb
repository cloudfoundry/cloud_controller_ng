require 'actions/services/mixins/service_broker_registration_error_parser'

module VCAP::CloudController
  class ServiceBrokerCreate
    class SpaceNotFound < StandardError; end

    include ServiceBrokerRegistrationErrorParser

    def initialize(service_manager, services_event_repository, warning_observer, access_validator, route_services_enabled, volume_services_enabled)
      @service_manager = service_manager
      @services_event_repository = services_event_repository
      @warning_observer = warning_observer
      @access_validator = access_validator
      @route_services_enabled = route_services_enabled
      @volume_services_enabled = volume_services_enabled
    end

    def create(params)
      if params[:space_guid]
        space_id = get_space_id_from_guid(params)
        params = params.merge({ space_id: })
      end

      broker = ServiceBroker.new(params)
      access_validator.validate_access(:create, broker, params)

      registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(
        broker,
        @service_manager,
        @services_event_repository,
        @route_services_enabled,
        @volume_services_enabled
      )
      raise get_exception_from_errors(registration) unless registration.create

      services_event_repository.record_broker_event(:create, broker, params)

      registration.warnings.each { |warning| warning_observer.add_warning(warning) } unless registration.warnings.empty?

      broker
    end

    private

    attr_reader :access_validator, :services_event_repository, :warning_observer

    def get_space_id_from_guid(params)
      space = Space.first(guid: params[:space_guid])
      raise ServiceBrokerCreate::SpaceNotFound unless space

      space.id
    end
  end
end
