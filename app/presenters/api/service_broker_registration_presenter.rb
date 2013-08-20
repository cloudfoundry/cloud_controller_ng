class ServiceBrokerRegistrationPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.broker.name,
      broker_url: @object.broker.broker_url
    }
  end

  def metadata_hash
    super.merge(
      url: "/v2/service_brokers/#{@object.broker.guid}"
    )
  end
end
