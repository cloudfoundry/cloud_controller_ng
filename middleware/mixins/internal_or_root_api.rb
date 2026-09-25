module CloudFoundry
  module Middleware
    module InternalOrRootApi
      def internal_api?(request)
        request.fullpath.match(%r{\A/internal})
      end

      def root_api?(request)
        request.fullpath.match(%r{\A(?:/v2/info|/v3|/|/healthz)\z})
      end
    end
  end
end
