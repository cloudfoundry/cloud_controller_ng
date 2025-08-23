require 'json'
require 'fileutils'

module RequestCaptureHelper
  # Configuration options
  @capture_enabled = ENV['CAPTURE_REQUESTS'] == 'true'  # Default: false
  @strip_test_mode_info = ENV['CAPTURE_STRIP_TEST_MODE_INFO'] != 'false'  # Default: true
  @capture_v3_only = ENV['CAPTURE_V3_ONLY'] != 'false'  # Default: true
  @output_file = nil
  @request_count = 0
  @file_mutex = Mutex.new

  def self.capture_enabled?
    @capture_enabled
  end

  def self.strip_test_mode_info?
    @strip_test_mode_info
  end

  def self.strip_test_mode_info=(value)
    @strip_test_mode_info = value
  end

  def self.capture_v3_only?
    @capture_v3_only
  end

  def self.capture_v3_only=(value)
    @capture_v3_only = value
  end

  def self.enable_capture
    @capture_enabled = true
    initialize_output_file
  end

  def self.disable_capture
    @capture_enabled = false
    finalize_output_file
  end

  def self.request_count
    @request_count
  end

  # todo configure file path
  def self.initialize_output_file(file_path = 'out/request_capture.json')
    return unless @capture_enabled
    
    @file_mutex.synchronize do
      FileUtils.mkdir_p(File.dirname(file_path))
      @output_file = File.open(file_path, 'w')
      @output_file.write("[\n")
      @output_file.flush
      @request_count = 0
    end
  end

  def self.finalize_output_file
    return unless @output_file
    
    @file_mutex.synchronize do
      @output_file.write("\n]\n")
      @output_file.close
      @output_file = nil
    end
  end

  def self.strip_test_mode_info_from_response(response_body)
    return response_body unless @strip_test_mode_info
    return response_body unless response_body.is_a?(Hash)
    
    # Deep clone to avoid modifying the original
    cleaned_body = JSON.parse(JSON.generate(response_body))
    
    # Strip test_mode_info from the root level
    cleaned_body.delete('test_mode_info')
    
    # Strip test_mode_info from errors array if it exists
    if cleaned_body['errors'].is_a?(Array)
      cleaned_body['errors'].each do |error|
        error.delete('test_mode_info') if error.is_a?(Hash)
      end
    end
    
    cleaned_body
  end

  def self.is_allowed_path?(path)
    return true unless @capture_v3_only
    
    # Allow root path, /v3/, and /v3/* paths only
    path == '/' || path.start_with?('/v3/') || path.start_with?('/v3')
  end

  def self.capture_request(method, path, body, headers, response)
    return unless @capture_enabled && @output_file
    
    # Skip requests that are not allowed paths when v3-only mode is enabled
    return unless is_allowed_path?(path)

    # Clean up headers - remove internal rack/test headers and normalize
    clean_headers = {}
    headers.each do |key, value|
      # Convert HTTP_X_Y format to X-Y format
      if key.start_with?('HTTP_')
        clean_key = key.sub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        clean_headers[clean_key] = value
      elsif %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
        clean_key = key.split('_').map(&:capitalize).join('-')
        clean_headers[clean_key] = value
      end
    end

    # Parse response body if it's JSON
    response_body = response.body
    parsed_response_body = nil
    begin
      parsed_response_body = JSON.parse(response_body) if response_body && !response_body.empty?
    rescue JSON::ParserError
      # Keep original body if not valid JSON
    end

    # Strip test_mode_info if configured and response body is parsed JSON
    if parsed_response_body
      parsed_response_body = strip_test_mode_info_from_response(parsed_response_body)
    end

    # Parse request body if it's JSON
    parsed_request_body = nil
    if body && !body.empty?
      begin
        parsed_request_body = JSON.parse(body)
      rescue JSON::ParserError
        parsed_request_body = body
      end
    end

    captured_data = {
      timestamp: Time.now.iso8601,
      request: {
        method: method.to_s.upcase,
        path: path,
        headers: clean_headers,
        body: parsed_request_body
      },
      response: {
        status: response.status,
        headers: response.headers,
        body: parsed_response_body || response_body
      }
    }

    @file_mutex.synchronize do
      # Add comma separator for all but the first request
      @output_file.write(",\n") if @request_count > 0
      
      # Write the request data as pretty JSON
      json_str = JSON.pretty_generate(captured_data)
      # Indent the JSON to match array formatting
      indented_json = json_str.lines.map.with_index do |line, index|
        index == 0 ? "  #{line}" : "  #{line}"
      end.join
      
      @output_file.write(indented_json.chomp)
      @output_file.flush  # Ensure immediate write to disk
      @request_count += 1
    end
  end

  # Hook into Rack::Test methods
  module RackTestInterceptor
    %w[get post put patch delete head options].each do |method|
      define_method(method) do |path, *args|
        # Extract parameters based on method signature
        # For GET/DELETE: (path, params, headers)
        # For POST/PUT/PATCH: (path, body, headers)
        params_or_body = args[0] || {}
        headers = args[1] || {}
        
        # Convert params to query string for GET requests, otherwise treat as body
        if %w[get delete head options].include?(method)
          body = nil
          # Only add query params if params_or_body is a non-empty hash
          if params_or_body.is_a?(Hash) && !params_or_body.empty?
            query_params = URI.encode_www_form(params_or_body)
            path = "#{path}#{path.include?('?') ? '&' : '?'}#{query_params}" unless query_params.empty?
          end
        else
          body = params_or_body.is_a?(String) ? params_or_body : params_or_body.to_json
        end

        # Call original method
        result = super(path, *args)
        
        # Capture the request/response if enabled
        if RequestCaptureHelper.capture_enabled?
          RequestCaptureHelper.capture_request(method, path, body, headers, last_response)
        end
        
        result
      end
    end
  end
end
