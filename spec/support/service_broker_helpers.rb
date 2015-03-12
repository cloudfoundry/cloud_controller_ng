module ServiceBrokerHelpers
  def stub_deprovision(service_instance, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'
    accepts_incomplete = opts[:accepts_incomplete]

    attrs = service_instance.client.attrs
    uri = URI(attrs[:url])
    uri.user = attrs[:auth_username]
    uri.password = attrs[:auth_password]

    plan = service_instance.service_plan
    service = plan.service

    uri = uri.to_s
    uri += "/v2/service_instances/#{service_instance.guid}"
    uri += "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}"

    uri += "&accepts_incomplete=#{accepts_incomplete}" unless accepts_incomplete.nil?

    stub_request(:delete, uri).to_return(status: status, body: body)
  end

  def stub_unbind(service_binding, opts={})
    status = opts[:status] || 200
    body = opts[:body] || '{}'

    service_instance = service_binding.service_instance
    attrs = service_instance.client.attrs
    uri = URI(attrs[:url])
    uri.user = attrs[:auth_username]
    uri.password = attrs[:auth_password]

    plan = service_instance.service_plan
    service = plan.service

    uri = uri.to_s
    uri += "/v2/service_instances/#{service_instance.guid}"

    uri += "/service_bindings/#{service_binding.guid}"
    stub_request(:delete, uri + "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}").to_return(status: status, body: body)
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
