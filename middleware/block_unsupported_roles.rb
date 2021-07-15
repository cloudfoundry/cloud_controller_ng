require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class BlockUnsupportedRoles
      def initialize(app, logger:)
        @app                   = app
        @logger                = logger
      end

      def call(env)
        # Wondering about the perf implications of this. Is it asking the DB if it's empty, or bringing back
        # the dataset and then seeing if it's empty. Would perfer the later.
        if VCAP::CloudController::SecurityContext.current_user.application_supported_spaces_dataset.empty?
          @app.call(env)
        else
          [401, { 'Content-Type' => 'text/html' }, 'None for you']
        end
      end
    end
  end
end
