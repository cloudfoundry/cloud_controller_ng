module VCAP::Services::ServiceBrokers
  class NullClient
    def unbind(_)
      {}
    end

    def deprovision(_, accepts_incomplete: false)
      {
        last_operation: {
          state: 'succeeded'
        }
      }
    end
  end
end
