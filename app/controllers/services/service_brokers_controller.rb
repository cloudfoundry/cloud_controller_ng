module VCAP::CloudController
  class ServiceBrokersController < RestController::Base

    post '/v2/service_brokers', :create
    def create
      raise NotAuthorized unless roles.admin?

      broker = Models::ServiceBroker.new(params)
      broker.save

      resource_url = "#{self.class.path}/#{broker.guid}"

      status = HTTP::CREATED
      headers = {"Location" => resource_url}

      body = {
        metadata: {
          guid: broker.guid,
          url: resource_url
        },
        entity: {
          name: broker.name,
          broker_url: broker.broker_url
        }
      }.to_json

      [status, headers, body]
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

    get '/v2/service_brokers', :enumerate
    def enumerate
      status = HTTP::OK
      headers = {}
      body = {
        service_brokers: Models::ServiceBroker.map do |broker|
          {
            'guid' => broker.guid,
            'name' => broker.name,
            'broker_url' => broker.broker_url,
          }
        end
      }.to_json

      [status, headers, body]
    end

    private

    def params
      Yajl::Parser.parse(body)
    end
  end
end
