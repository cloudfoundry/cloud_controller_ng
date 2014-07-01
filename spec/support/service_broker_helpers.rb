module ServiceBrokerHelpers
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
