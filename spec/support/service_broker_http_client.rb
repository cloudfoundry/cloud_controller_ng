RSpec.configure do |config|
  config.before do
    fake = double('HttpClient')

    fake.stub(:provision).and_return({
      'service_id' => Sham.guid,
      'configuration' => 'CONFIGURATION',
      'credentials' => Sham.service_credentials,
      'dashboard_url' => 'http://dashboard.example.com'
    })

    fake.stub(:bind).and_return({
      'service_id' => Sham.guid,
      'configuration' => 'CONFIGURATION',
      'credentials' => Sham.service_credentials,
      'syslog_drain_url' => 'http://syslog.example.com'
    })

    fake.stub(:unbind)
    fake.stub(:deprovision)

    VCAP::Services::ServiceBrokers::V1::HttpClient.stub(:new).and_return(fake)
  end
end
