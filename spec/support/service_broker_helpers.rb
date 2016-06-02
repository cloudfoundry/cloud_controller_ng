module ServiceBrokerHelpers
  def stub_provision(broker, opts={}, &block)
    url = provision_url_for_broker(broker, accepts_incomplete: opts[:accepts_incomplete])
    status = opts[:status] || 201
    body = opts[:body] || '{}'
    if block
      stub_request(:put, url).to_return(&block)
    else
      stub_request(:put, url).to_return(status: status, body: body)
    end
  end

  def stub_update(service_instance, opts={}, &block)
    status = opts[:status] || 200
    body = opts[:body] || '{}'
    accepts_incomplete = opts[:accepts_incomplete]
    url = update_url_for_broker(service_instance, accepts_incomplete: accepts_incomplete)
    if block
      stub_request(:patch, url).to_return(&block)
    else
      stub_request(:patch, url).to_return(status: status, body: body)
    end
  end

  def stub_deprovision(service_instance, opts={}, &block)
    status = opts[:status] || 200
    body = opts[:body] || '{}'
    accepts_incomplete = opts[:accepts_incomplete]

    url = deprovision_url(service_instance, accepts_incomplete: accepts_incomplete)

    if block
      stub_request(:delete, url).to_return(&block)
    else
      stub_request(:delete, url).
        to_return(status: status, body: body)
    end
  end

  def stub_bind(service_instance, opts={}, &block)
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    fake_service_binding = opts[:fake_service_binding] || VCAP::CloudController::ServiceBinding.new(service_instance: service_instance, guid: '')

    if block
      stub_request(:put, /#{service_binding_url(fake_service_binding)}[A-Za-z0-9-]+/).
        to_return(&block)
    else
      stub_request(:put, /#{service_binding_url(fake_service_binding)}[A-Za-z0-9-]+/).
        to_return(status: status, body: body)
    end
  end

  def stub_unbind(service_binding, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    stub_request(:delete, unbind_url(service_binding)).
      to_return(status: status, body: body)
  end

  def stub_unbind_for_instance(service_instance, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    fake_service_binding = VCAP::CloudController::ServiceBinding.new(service_instance: service_instance, guid: '')

    stub_request(:delete, /#{service_binding_url(fake_service_binding)}[A-Za-z0-9-]+/).
      to_return(status: status, body: body)
  end

  def provision_url_for_broker(broker, accepts_incomplete: nil)
    path = "/v2/service_instances/#{guid_pattern}"
    async_query = "accepts_incomplete=#{accepts_incomplete}" if !accepts_incomplete.nil?
    query_params = async_query ? "\\?#{async_query}" : ''

    /#{build_broker_url(broker.client.attrs)}#{path}#{query_params}/
  end

  def update_url_for_broker(broker, accepts_incomplete: nil)
    path = "/v2/service_instances/#{guid_pattern}"
    async_query = "accepts_incomplete=#{accepts_incomplete}" if !accepts_incomplete.nil?
    query_params = async_query ? "\\?#{async_query}" : ''

    /#{build_broker_url(broker.client.attrs)}#{path}#{query_params}/
  end

  def update_url(service_instance)
    service_instance_url(service_instance, '')
  end

  def bind_url(service_instance, query: nil)
    path = "/v2/service_instances/#{service_instance.guid}/service_bindings/#{guid_pattern}"
    query_params = !query.nil? ? "\\?#{query}" : ''
    /#{build_broker_url(service_instance.client.attrs)}#{path}#{query_params}/
  end

  def unbind_url(service_binding)
    plan = service_binding.service_instance.service_plan
    service = plan.service
    query = "plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"
    service_binding_url(service_binding, query)
  end

  def deprovision_url(service_instance, accepts_incomplete: nil)
    plan = service_instance.service_plan
    service = plan.service

    query = "plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"
    query += "&accepts_incomplete=#{accepts_incomplete}" unless accepts_incomplete.nil?

    service_instance_url(service_instance, query)
  end

  def last_operation_state_url(service_instance)
    params = "plan_id=#{service_instance.service_plan.broker_provided_id}&service_id=#{service_instance.service.broker_provided_id}"
    params = "operation=#{service_instance.last_operation.broker_provided_operation}&" + params if service_instance.last_operation.broker_provided_operation
    "#{service_instance_url(service_instance)}/last_operation?" + params
  end

  def service_instance_url(service_instance, query=nil)
    path = "/v2/service_instances/#{service_instance.guid}"
    build_broker_url(service_instance.client.attrs, path, query)
  end

  def service_binding_url(service_binding, query=nil)
    service_instance = service_binding.service_instance
    path = "/v2/service_instances/#{service_instance.guid}"
    path += "/service_bindings/#{service_binding.guid}"
    build_broker_url(service_instance.client.attrs, path, query)
  end

  def remove_basic_auth(url)
    uri = URI(url)
    uri.user = nil
    uri.password = nil
    uri.query = nil
    uri.to_s
  end

  def guid_pattern
    '[[:alnum:]-]+'
  end

  def build_broker_url(client_attrs, relative_path=nil, query=nil)
    uri = URI(client_attrs.fetch(:url))
    uri.user = client_attrs.fetch(:auth_username)
    uri.password = client_attrs.fetch(:auth_password)
    uri.path += relative_path if relative_path
    uri.query = query if query
    uri.to_s
  end
end
