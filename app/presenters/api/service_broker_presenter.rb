require_relative 'api_presenter'

class ServiceBrokerPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name,
      broker_url: @object.broker_url,
      auth_username: @object.auth_username,
    }
  end

  def metadata_hash
    super.merge(
      url: "/v2/service_brokers/#{@object.guid}"
    )
  end
end
