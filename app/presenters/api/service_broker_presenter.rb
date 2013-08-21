class ServiceBrokerPresenter < ApiPresenter
  def entity_hash
    {
      name: @object.name,
      broker_url: @object.broker_url
    }
  end

  def metadata_hash
    super.merge(
      url: "/v2/service_brokers/#{@object.guid}"
    )
  end
end
