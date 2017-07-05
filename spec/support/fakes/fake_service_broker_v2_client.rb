class FakeServiceBrokerV2Client
  attr_accessor :credentials
  attr_accessor :syslog_drain_url
  attr_accessor :volume_mounts
  attr_accessor :service_name
  attr_accessor :plan_name
  attr_accessor :plan_schemas

  def initialize(_attrs)
    @credentials = { 'username' => 'cool_user' }
    @syslog_drain_url = 'syslog://drain.example.com'
    @volume_mounts = []
    @service_name = 'service_name'
    @plan_name = 'fake_plan_name'
    @plan_schemas = nil
  end

  def catalog
    {
      'services' => [{
        'id'          => 'service_id',
        'name'        => service_name,
        'description' => 'some description',
        'bindable'    => true,
        'plans'       => [{
          'id'          => 'fake_plan_id',
          'name'        => plan_name,
          'description' => 'fake_plan_description',
          'schemas'     => plan_schemas
        }]
      }]
    }
  end

  def provision(_instance, arbitrary_parameters: {}, accepts_incomplete: false)
    {
      instance: {
        credentials:   {},
        dashboard_url: nil
      },
      last_operation: {
        type:        'create',
        description: '',
        state:       'succeeded'
      }
    }
  end

  def bind(_binding, _arbitrary_parameters)
    {
      credentials: credentials,
      syslog_drain_url: syslog_drain_url,
      volume_mounts: volume_mounts,
    }
  end

  def unbind(_binding); end
end
