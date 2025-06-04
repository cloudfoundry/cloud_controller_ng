module VCAP::CloudController
  module Diego
    class DesireAppHandler
      class << self
        def create_or_update_app(process, client)
          if (existing_lrp = client.get_app(process))
            client.update_app(process, existing_lrp)
          else
            begin
              client.desire_app(process)
            rescue CloudController::Errors::ApiError => e # catch race condition if Diego Process Sync creates an LRP in the meantime
              if e.name == 'RunnerError' && e.message['the requested resource already exists']
                existing_lrp = client.get_app(process)
                client.update_app(process, existing_lrp)
              end
            end
          end
        end
      end
    end
  end
end
