module VCAP::CloudController
  module Diego
    module Common
      class Protocol
        def stop_index_request(app, index)
          ['diego.stop.index', stop_index_message(app, index).to_json]
        end

        private

        def stop_index_message(app, index)
          {
            'process_guid' => ProcessGuid.from_app(app),
            'index' => index,
          }
        end
      end
    end
  end
end
