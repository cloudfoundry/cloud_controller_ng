module VCAP::CloudController
  module Diego
    class DesireAppHandler
      class << self
        def create_or_update_app(process, client)
          if (existing_lrp = client.get_app(process))
            client.update_app(process, existing_lrp)
          else
            client.desire_app(process)
          end
        end
      end
    end
  end
end
