class FakeServiceBrokerV2Client
  attr_accessor :credentials, :syslog_drain_url, :volume_mounts, :service_name, :plan_name, :plan_schemas, :parameters

  def initialize(_attrs={})
    @credentials = { 'username' => 'cool_user' }
    @syslog_drain_url = 'syslog://drain.example.com'
    @volume_mounts = []
    @service_name = 'service_name'
    @plan_name = 'fake_plan_name'
    @plan_schemas = nil
    @parameters = {}
  end

  def catalog(user_guid: nil)
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

  def provision(_instance, arbitrary_parameters: {}, accepts_incomplete: false, maintenance_info: {})
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

  def deprovision(_instance, arbitrary_parameters: {}, accepts_incomplete: false)
    {
      last_operation: {
        type:        'delete',
        description: '',
        state:       'succeeded'
      }
    }
  end

  def update(_instance, _plan, accepts_incomplete: false, arbitrary_parameters: nil, previous_values: {}, maintenance_info: nil)
    [{
      last_operation: {
        type:        'update',
        description: '',
        state:       'succeeded'
      },
    }, nil]
  end

  def bind(_binding, _arbitrary_parameters, _accepts_incomplete=nil)
    {
      async: false,
      binding: {
        credentials: credentials,
        syslog_drain_url: syslog_drain_url,
        volume_mounts: volume_mounts,
      }
    }
  end

  def unbind(*)
    {
      async: false
    }
  end

  def fetch_service_instance(_instance)
    parameters
  end

  def fetch_service_binding(_binding)
    parameters
  end

  class WithInvalidCatalog
    def catalog
      {}
    end
  end

  class WithConflictingUAAClient < FakeServiceBrokerV2Client
    def catalog(user_guid: nil)
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
          }],
          'dashboard_client' => {
            'id' => 'some-uaa-id',
            'secret' => 'my-dashboard-secret',
            'redirect_uri' => 'http://example.org'
          }
        }]
      }
    end
  end
end
