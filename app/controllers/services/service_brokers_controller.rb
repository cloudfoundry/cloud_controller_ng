require 'presenters/api/service_broker_presenter'

module VCAP::CloudController

  # This controller is an experiment breaking away from the old
  # cloudcontroller metaprogramming. We manually generate the JSON
  # expected by CFoundry and CF.
  class ServiceBrokersController < RestController::ModelController
    class ServiceBrokerMessage < VCAP::RestAPI::Message
      optional :name,       String
      optional :broker_url, String
      optional :auth_username,   String
      optional :auth_password,   String

      def self.extract(json)
        decode(json).extract
      end
    end

    get '/v2/service_brokers', :enumerate
    def enumerate
      validate_access(:index, ServiceBroker, user, roles)
      headers = {}
      brokers = ServiceBroker.filter(build_filter)

      body = paginate( brokers.map { |broker| ServiceBrokerPresenter.new(broker).to_hash } )
      [HTTP::OK, headers, body.to_json]
    end

    post '/v2/service_brokers', :create
    def create
      validate_access(:create, ServiceBroker, user, roles)
      params = ServiceBrokerMessage.extract(body)
      broker = ServiceBroker.new(params)

      registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(broker)

      unless registration.create
        raise get_exception_from_errors(registration)
      end

      if !registration.warnings.empty?
        registration.warnings.each { |warning| add_warning(warning) }
      end

      headers = {'Location' => url_of(broker)}
      body = ServiceBrokerPresenter.new(broker).to_json
      [HTTP::CREATED, headers, body]
    end

    put '/v2/service_brokers/:guid', :update
    def update(guid)
      validate_access(:update, ServiceBroker, user, roles)
      params = ServiceBrokerMessage.extract(body)
      broker = ServiceBroker.find(guid: guid)
      return HTTP::NOT_FOUND unless broker

      broker.set(params)
      registration = VCAP::Services::ServiceBrokers::ServiceBrokerRegistration.new(broker)

      unless registration.update
        raise get_exception_from_errors(registration)
      end

      if !registration.warnings.empty?
        registration.warnings.each { |warning| add_warning(warning) }
      end

      body = ServiceBrokerPresenter.new(broker).to_json
      [HTTP::OK, {}, body]
    end

    delete '/v2/service_brokers/:guid', :delete
    def delete(guid)
      validate_access(:delete, ServiceBroker, user, roles)
      broker = ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless broker
      VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(broker).execute!
      HTTP::NO_CONTENT
    rescue Sequel::ForeignKeyConstraintViolation
      raise VCAP::Errors::ApiError.new_from_details("ServiceBrokerNotRemovable")
    end

    def self.translate_validation_exception(e, _)
      if e.errors.on(:name) && e.errors.on(:name).include?(:unique)
        Errors::ApiError.new_from_details("ServiceBrokerNameTaken", e.model.name)
      elsif e.errors.on(:broker_url) && e.errors.on(:broker_url).include?(:unique)
        Errors::ApiError.new_from_details("ServiceBrokerUrlTaken", e.model.broker_url)
      else
        Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", e.errors.full_messages)
      end
    end

    private

    def build_filter
      q = params['q']
      if q && q.start_with?('name:')
        {:name => q.split(':')[1]}
      else
        {}
      end
    end

    def paginate(resources)
      {
        'total_results' => resources.count,
        'total_pages' => 1,
        'prev_url' => nil,
        'next_url' => nil,
        'resources' => resources
      }
    end

    def url_of(broker)
      "#{self.class.path}/#{broker.guid}"
    end

    def get_exception_from_errors(registration)
      errors = registration.errors
      broker = registration.broker

      if errors.on(:broker_url) && errors.on(:broker_url).include?(:url)
        Errors::ApiError.new_from_details("ServiceBrokerUrlInvalid", broker.broker_url)
      elsif errors.on(:broker_url) && errors.on(:broker_url).include?(:unique)
        Errors::ApiError.new_from_details("ServiceBrokerUrlTaken", broker.broker_url)
      elsif errors.on(:name) && errors.on(:name).include?(:unique)
        Errors::ApiError.new_from_details("ServiceBrokerNameTaken", broker.name)
      elsif errors.on(:services)
        Errors::ApiError.new_from_details("ServiceBrokerInvalid", errors.on(:services))
      else
        Errors::ApiError.new_from_details("ServiceBrokerInvalid", errors.full_messages)
      end
    end
  end
end
