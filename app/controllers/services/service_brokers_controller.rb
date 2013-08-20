require 'presenters/api/service_broker_registration_presenter'

module VCAP::CloudController

  # This controller is an experiment breaking away from the old
  # cloudcontroller metaprogramming. We manually generate the JSON
  # expected by CFoundry and CF.
  class ServiceBrokersController < RestController::Base
    class ServiceBrokerMessage < VCAP::RestAPI::Message
      optional :name,       String
      optional :broker_url, String
      optional :token,      String

      def self.extract(json)
        decode(json).extract
      end
    end

    get '/v2/service_brokers', :enumerate
    post '/v2/service_brokers', :create
    put '/v2/service_brokers/:guid', :update
    delete '/v2/service_brokers/:guid', :delete

    # poor man's before filter
    def dispatch(op, *args)
      require_admin
      super
    end

    def enumerate
      headers = {}
      brokers = Models::ServiceBroker.filter(build_filter)

      body = paginate( brokers.map { |broker| broker_hash(broker) } )
      [HTTP::OK, headers, body.to_json]
    end

    def create
      params = ServiceBrokerMessage.extract(body)

      registration = Models::ServiceBrokerRegistration.new(params)

      unless registration.save(raise_on_failure: false)
        raise get_exception_from_errors(registration)
      end

      headers = {'Location' => "/v2/service_brokers/#{registration.broker.guid}"}
      body = ServiceBrokerRegistrationPresenter.new(registration).to_json
      [HTTP::CREATED, headers, body]
    end

    def update(guid)
      broker = Models::ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless broker

      broker.set(ServiceBrokerMessage.extract(body))

      broker.check! if broker.valid?
      broker.save

      body = broker_hash(broker)
      [ HTTP::OK, {}, body.to_json ]
    end

    def delete(guid)
      broker = Models::ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless broker
      broker.destroy
      HTTP::NO_CONTENT
    end

    def self.translate_validation_exception(e, _)
      if e.errors.on(:name) && e.errors.on(:name).include?(:unique)
        Errors::ServiceBrokerNameTaken.new(e.model.name)
      elsif e.errors.on(:broker_url) && e.errors.on(:broker_url).include?(:unique)
        Errors::ServiceBrokerUrlTaken.new(e.model.broker_url)
      else
        Errors::ServiceBrokerInvalid.new(e.errors.full_messages)
      end
    end

    private

    def require_admin
      raise NotAuthenticated unless user
      raise NotAuthorized unless roles.admin?
    end

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

    def broker_hash(broker)
      {
        'metadata' => {
          'guid' => broker.guid,
          'url' => url_of(broker),
          'created_at' => broker.created_at,
          'updated_at' => broker.updated_at,
        },
        'entity' => {
          'name' => broker.name,
          'broker_url' => broker.broker_url,
        }
      }
    end

    def url_of(broker)
      "#{self.class.path}/#{broker.guid}"
    end

    private

    def get_exception_from_errors(registration)
      errors = registration.errors

      if errors.on(:broker_api) && errors.on(:broker_api).include?(:authentication_failed)
        Errors::ServiceBrokerApiAuthenticationFailed.new(registration.broker_url)
      elsif errors.on(:broker_api) && errors.on(:broker_api).include?(:unreachable)
        Errors::ServiceBrokerApiUnreachable.new(registration.broker_url)
      elsif errors.on(:broker_api) && errors.on(:broker_api).include?(:timeout)
        Errors::ServiceBrokerApiTimeout.new(registration.broker_url)
      elsif errors.on(:broker_url) && errors.on(:broker_url).include?(:unique)
        Errors::ServiceBrokerUrlTaken.new(registration.broker_url)
      elsif errors.on(:name) && errors.on(:name).include?(:unique)
        Errors::ServiceBrokerNameTaken.new(registration.name)
      elsif errors.on(:catalog) && errors.on(:catalog).include?(:malformed)
        Errors::ServiceBrokerCatalogMalformed.new
      else
        Errors::ServiceBrokerInvalid.new(errors.full_messages)
      end
    end
  end
end
