module VCAP::CloudController
  class DatabaseUriGenerator
    VALID_DB_TYPES = %w(mysql mysql2 postgres postgresql tinytds).freeze
    RAILS_STYLE_DATABASE_TO_ADAPTER_MAPPING = {
      'mysql' => 'mysql2',
      'postgresql' => 'postgres'
    }.freeze

    def initialize(service_uris)
      @service_uris = service_uris || []
    end

    def database_uri
      uri = bound_relational_database_uri
      convert_scheme_to_rails_style_adapter(uri).to_s if uri
    end

    private

    def bound_relational_database_uri
      @service_uris.each do |service_uri|
        begin
          uri = URI.parse(service_uri)
          return uri if VALID_DB_TYPES.include?(uri.scheme)
        rescue URI::InvalidURIError
        end
      end

      nil
    end

    def convert_scheme_to_rails_style_adapter(uri)
      uri.scheme = RAILS_STYLE_DATABASE_TO_ADAPTER_MAPPING[uri.scheme] if RAILS_STYLE_DATABASE_TO_ADAPTER_MAPPING[uri.scheme]
      uri
    end
  end
end
