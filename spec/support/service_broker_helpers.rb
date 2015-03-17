module ServiceBrokerHelpers
  def stub_deprovision(service_instance, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'
    accepts_incomplete = opts[:accepts_incomplete]

    plan = service_instance.service_plan
    service = plan.service

    query = "plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"
    query += "&accepts_incomplete=#{accepts_incomplete}" unless accepts_incomplete.nil?

    stub_request(:delete, service_instance_url(service_instance, query)).
      to_return(status: status, body: body)
  end

  def stub_bind(service_instance, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    fake_service_binding = VCAP::CloudController::ServiceBinding.new(service_instance: service_instance, guid: '')

    stub_request(:put, /#{service_binding_url(fake_service_binding)}[A-Za-z0-9-]+/).
      to_return(status: status, body: body)
  end

  def stub_unbind(service_binding, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    plan = service_binding.service_instance.service_plan
    service = plan.service
    query = "plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"

    stub_request(:delete, service_binding_url(service_binding, query)).
      to_return(status: status, body: body)
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

  def build_broker_url(client_attrs, relative_path=nil, query=nil)
    uri = URI(client_attrs.fetch(:url))
    uri.user = client_attrs.fetch(:auth_username)
    uri.password = client_attrs.fetch(:auth_password)
    uri.path += relative_path if relative_path
    uri.query = query if query
    uri.to_s
  end

  def stub_v1_broker
    fake = double('HttpClient')

    allow(fake).to receive(:provision).and_return({
      'service_id' => Sham.guid,
      'configuration' => 'CONFIGURATION',
      'credentials' => Sham.service_credentials,
      'dashboard_url' => 'http://dashboard.example.com'
    })

    allow(fake).to receive(:bind).and_return({
      'service_id' => Sham.guid,
      'configuration' => 'CONFIGURATION',
      'credentials' => Sham.service_credentials,
      'syslog_drain_url' => 'http://syslog.example.com'
    })

    allow(fake).to receive(:unbind)
    allow(fake).to receive(:deprovision)

    allow(VCAP::Services::ServiceBrokers::V1::HttpClient).to receive(:new).and_return(fake)
  end
end
