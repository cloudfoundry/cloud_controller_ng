module Fog
  module Google
    class SQL
      class Real
        include Fog::Google::Shared

        attr_accessor :client
        attr_reader :sql

        def initialize(options)
          shared_initialize(options[:google_project], GOOGLE_SQL_API_VERSION, GOOGLE_SQL_BASE_URL)
          options[:google_api_scope_url] = GOOGLE_SQL_API_SCOPE_URLS.join(" ")

          initialize_google_client(options)
          @sql = ::Google::Apis::SqladminV1beta4::SQLAdminService.new
          apply_client_options(@sql, options)
        end
      end
    end
  end
end
