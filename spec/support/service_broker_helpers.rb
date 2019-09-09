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
    url = update_url_for_broker(service_instance.service_broker, accepts_incomplete: accepts_incomplete)
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

  def basic_auth(service_binding: nil, service_instance: nil, service_broker: nil)
    broker = if service_binding
               service_binding.service_instance.service_broker
             elsif service_instance
               service_instance.service_broker
             else
               service_broker
             end
    username = broker.auth_username
    password = broker.auth_password
    [username, password]
  end

  def stub_unbind(service_binding, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'
    accepts_incomplete = opts[:accepts_incomplete] || nil

    stub_request(:delete, unbind_url(service_binding, accepts_incomplete: accepts_incomplete)).
      with(basic_auth: basic_auth(service_binding: service_binding)).
      to_return(status: status, body: body)
  end

  def stub_unbind_for_instance(service_instance, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    fake_service_binding = VCAP::CloudController::ServiceBinding.new(service_instance: service_instance, guid: '')

    stub_request(:delete, /#{service_binding_url(fake_service_binding)}[A-Za-z0-9-]+/).
      to_return(status: status, body: body)
  end

  def stub_delete(broker, opts={})
    status = opts[:status] || 204
    body = opts[:body] || '{}'

    stub_request(:delete, delete_broker_url(broker)).
      with(basic_auth: basic_auth(service_broker: broker)).
      to_return(status: status, body: body)
  end

  def provision_url_for_broker(broker, accepts_incomplete: nil)
    path = "/v2/service_instances/#{guid_pattern}"
    async_query = "accepts_incomplete=#{accepts_incomplete}" if !accepts_incomplete.nil?
    query_params = async_query ? "\\?#{async_query}" : ''

    /#{build_broker_url(broker)}#{path}#{query_params}/
  end

  def update_url_for_broker(broker, accepts_incomplete: nil)
    path = "/v2/service_instances/#{guid_pattern}"
    async_query = "accepts_incomplete=#{accepts_incomplete}" if !accepts_incomplete.nil?
    query_params = async_query ? "\\?#{async_query}" : ''

    /#{build_broker_url(broker)}#{path}#{query_params}/
  end

  def update_url(service_instance, accepts_incomplete: nil)
    query = 'accepts_incomplete=true' if accepts_incomplete
    service_instance_url(service_instance, query)
  end

  def bind_url(service_instance, accepts_incomplete: nil)
    path = "/v2/service_instances/#{service_instance.guid}/service_bindings/#{guid_pattern}"
    async_query = "accepts_incomplete=#{accepts_incomplete}" if !accepts_incomplete.nil?
    query_params = async_query ? "\\?#{async_query}" : ''

    /#{build_broker_url(service_instance.service_broker)}#{path}#{query_params}/
  end

  def unbind_url(service_binding, accepts_incomplete: nil)
    plan = service_binding.service_instance.service_plan
    service = plan.service
    query = 'accepts_incomplete=true&' if accepts_incomplete
    query = "#{query}plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"
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
    build_broker_url(service_instance.service_broker, path, query)
  end

  def service_binding_url(service_binding, query=nil)
    service_instance = service_binding.service_instance
    path = "/v2/service_instances/#{service_instance.guid}"
    path += "/service_bindings/#{service_binding.guid}"
    build_broker_url(service_instance.service_broker, path, query)
  end

  def delete_broker_url(broker)
    build_broker_url(broker)
  end

  def remove_basic_auth(url)
    uri = URI(url)
    uri.user = nil
    uri.password = nil
    uri.query = nil
    uri.to_s
  end

  def guid_pattern
    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}'
  end

  def build_broker_url_from_params(url, relative_path=nil, query=nil)
    uri = URI(url)
    uri.path += relative_path if relative_path
    uri.query = query if query
    uri.to_s
  end

  def build_broker_url(broker, relative_path=nil, query=nil)
    uri = URI(broker.broker_url)
    uri.path += relative_path if relative_path
    uri.query = query if query
    uri.to_s
  end
end
