require 'presenters/api/service_broker_presenter'

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
      brokers = ServiceBroker.filter(build_filter)

      body = paginate( brokers.map { |broker| ServiceBrokerPresenter.new(broker).to_hash } )
      [HTTP::OK, headers, body.to_json]
    end

    def create
      params = ServiceBrokerMessage.extract(body)
      broker = ServiceBroker.new(params)

      registration = ServiceBrokerRegistration.new(broker)

      unless registration.save(raise_on_failure: false)
        raise get_exception_from_errors(registration)
      end

      headers = {'Location' => url_of(broker)}
      body = ServiceBrokerPresenter.new(broker).to_json
      [HTTP::CREATED, headers, body]
    end

    def update(guid)
      params = ServiceBrokerMessage.extract(body)
      broker = ServiceBroker.find(guid: guid)
      return HTTP::NOT_FOUND unless broker

      registration = ServiceBrokerRegistration.new(broker)

      broker.set(params)

      unless registration.save(raise_on_failure: false)
        raise get_exception_from_errors(registration)
      end

      body = ServiceBrokerPresenter.new(broker).to_json
      [HTTP::OK, {}, body]
    end

    def delete(guid)
      broker = ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless broker
      broker.destroy
      HTTP::NO_CONTENT
    rescue Sequel::ForeignKeyConstraintViolation
      raise VCAP::Errors::ServiceBrokerNotRemovable.new
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

    def url_of(broker)
      "#{self.class.path}/#{broker.guid}"
    end

    private

    def get_exception_from_errors(registration)
      errors = registration.errors
      broker = registration.broker

      if errors.on(:broker_url) && errors.on(:broker_url).include?(:url)
        Errors::ServiceBrokerUrlInvalid.new(broker.broker_url)
      elsif errors.on(:broker_url) && errors.on(:broker_url).include?(:unique)
        Errors::ServiceBrokerUrlTaken.new(broker.broker_url)
      elsif errors.on(:name) && errors.on(:name).include?(:unique)
        Errors::ServiceBrokerNameTaken.new(broker.name)
      else
        Errors::ServiceBrokerInvalid.new(errors.full_messages)
      end
    end
  end
end
