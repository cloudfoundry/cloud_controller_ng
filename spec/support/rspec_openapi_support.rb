if ENV['OPENAPI']
  # Temporarily unset OPENAPI so the gem doesn't register its own hooks.
  # We register our own after(:each) that rescues errors from specs that
  # intentionally send malformed requests.
  openapi_flag = ENV.delete('OPENAPI')
  require 'rspec/openapi'
  ENV['OPENAPI'] = openapi_flag

  RSpec::OpenAPI.path = ->(example) {
    relative = example.file_path.sub(%r{^\./}, '')
    if relative.end_with?('_spec.rb')
      basename = File.basename(relative, '_spec.rb')
      "docs/openapi/#{basename}.yaml"
    else
      'docs/openapi/_skip.yaml'
    end
  }
  RSpec::OpenAPI.title = 'Cloud Controller V3 API'
  RSpec::OpenAPI.application_version = 'v3'
  RSpec::OpenAPI.example_types = %i[request] + [nil]
  RSpec::OpenAPI.ignored_paths = [%r{^/v2/}, %r{^/_internal/}]

  # CCNG request specs use Rack::Test::Methods (providing last_request /
  # last_response) against a composite Rack app where Rails is mounted at
  # /v3.  This extractor bridges the two:
  #   - request_response: wraps Rack::Test objects into ActionDispatch
  #   - request_attributes: sets SCRIPT_NAME=/v3 so the Rails router can
  #     match the route and parameterize the path correctly
  class << (RSpec::OpenAPI::Extractors::CCNG = Object.new)
    def request_response(context)
      RSpec::OpenAPI::Extractors::Rack.request_response(context)
    rescue Rack::Test::Error
      [nil, nil]
    end

    def request_attributes(request, example)
      path_info = request.path_info

      if path_info.start_with?('/v3')
        rails_path = path_info.delete_prefix('/v3')
        rails_path = '/' if rails_path.empty?

        route, parameterized = find_rails_route(request, rails_path)

        if route && parameterized
          raw_path_params = route.required_parts.each_with_object({}) do |part, hash|
            hash[part] = begin
              request.params[part.to_s]
            rescue ActionDispatch::Http::Parameters::ParseError
              nil
            end || request.path_parameters[part]
          end

          summary, tags, formats, operation_id, required_request_params, security,
            description, deprecated, example_mode, example_key, example_name,
            response_enum, request_enum = SharedExtractor.attributes(example)

          summary ||= route.requirements[:action]
          tags ||= [route.requirements[:controller]&.classify].compact
          raw_path_params = raw_path_params.reject { |k, _| RSpec::OpenAPI.ignored_path_params.include?(k) }

          return [
            "/v3#{parameterized}", summary, tags, operation_id,
            required_request_params, raw_path_params, description, security,
            deprecated, formats, example_mode, example_key, example_name,
            response_enum, request_enum
          ]
        end
      end

      RSpec::OpenAPI::Extractors::Rack.request_attributes(request, example)
    end

    private

    def find_rails_route(request, rails_path)
      env = request.env.dup
      env['PATH_INFO'] = rails_path
      env['SCRIPT_NAME'] = '/v3'
      mock_request = ActionDispatch::Request.new(env)

      Rails.application.routes.router.recognize(mock_request) do |route, parameters|
        path = route.path.spec.to_s.delete_suffix('(.:format)')
        return [route, path] if route.app.matches?(mock_request)
      end

      [nil, nil]
    end
  end

  module SharedHooks
    def self.find_extractor
      RSpec::OpenAPI::Extractors::CCNG
    end
  end

  # rspec-openapi doesn't handle BigDecimal in type detection or YAML
  # serialization. CCNG uses Oj which parses JSON floats as BigDecimal.
  # We patch both: type detection (so schema says "number") and the
  # record builder (so example values are plain Float, not YAML-tagged).
  require 'bigdecimal'

  RSpec::OpenAPI::SchemaBuilder.singleton_class.prepend(Module.new do
    private

    def build_type(value, format: nil, enum: nil)
      if !format && value.is_a?(BigDecimal)
        result = { type: 'number', format: 'double' }
        result[:enum] = enum if enum
        return result
      end

      super
    end
  end)

  RSpec::OpenAPI::RecordBuilder.singleton_class.prepend(Module.new do
    private

    def safe_parse_body(response, media_type)
      convert_bigdecimals(super)
    end

    def raw_request_params(request)
      convert_bigdecimals(super)
    end

    def convert_bigdecimals(obj)
      case obj
      when BigDecimal then obj.to_f
      when Hash then obj.transform_values { |v| convert_bigdecimals(v) }
      when Array then obj.map { |v| convert_bigdecimals(v) }
      else obj
      end
    end
  end)

  RSpec.configuration.after(:each) do |example|
    if RSpec::OpenAPI.example_types.include?(example.metadata[:type]) && example.metadata[:openapi] != false
      path = RSpec::OpenAPI.path.then { |p| p.is_a?(Proc) ? p.call(example) : p }
      next if path.end_with?('_skip.yaml')

      record = RSpec::OpenAPI::RecordBuilder.build(self, example: example, extractor: SharedHooks.find_extractor)
      RSpec::OpenAPI.path_records[path] << record if record
    end
  rescue Rack::Test::Error, ActionDispatch::Http::Parameters::ParseError
    nil
  end

  RSpec.configuration.after(:suite) do
    result_recorder = RSpec::OpenAPI::ResultRecorder.new(RSpec::OpenAPI.path_records)
    result_recorder.record_results!
    if result_recorder.errors?
      error_message = result_recorder.error_message
      colorizer = RSpec::Core::Formatters::ConsoleCodes
      RSpec.configuration.reporter.message colorizer.wrap(error_message, :failure)
    end
  end
end
