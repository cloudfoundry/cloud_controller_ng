module ControllerHelpers
  include VCAP::CloudController

  def self.description_for_inline_depth(depth, pagination=50)
    if depth
      "?inline-relations-depth=#{depth}&results-per-page=#{pagination}"
    else
      ''
    end
  end

  def query_params_for_inline_depth(depth, pagination=50)
    if depth
      { 'inline-relations-depth' => depth, 'results-per-page' => pagination }
    else
      { 'results-per-page' => pagination }
    end
  end

  def normalize_attributes(value)
    case value
    when Hash
      stringified = {}

      value.each do |k, v|
        stringified[k] = normalize_attributes(v)
      end

      stringified
    when Array
      value.collect { |x| normalize_attributes(x) }
    when Numeric, nil, true, false
      value
    when Time
      value.iso8601
    else
      value.to_s
    end
  end

  def app
    FakeFrontController.new(TestConfig.config_instance)
  end

  def admin_headers_for(user, opts={})
    headers_for(user, opts.merge(admin: true))
  end

  def headers_for(user, opts={})
    generated_email = Sham.email
    opts = { email: generated_email,
             https: false }.merge(opts)

    headers = {}
    token = opts[:client] ? client_token(user, opts) : user_token(user, opts)
    headers['HTTP_AUTHORIZATION'] = "bearer #{token}"

    headers['HTTP_X_FORWARDED_PROTO'] = 'https' if opts[:https]
    result = json_headers(headers)

    result.define_singleton_method('_generated_email') do
      generated_email
    end

    result
  end

  def json_headers(headers)
    headers.merge({ 'CONTENT_TYPE' => 'application/json' })
  end

  def form_headers(headers)
    headers.merge({ 'CONTENT_TYPE' => 'multipart/form-data' })
  end

  def yml_headers(headers)
    headers.merge({ 'CONTENT_TYPE' => 'application/x-yaml' })
  end

  def decoded_response(options={})
    parse(last_response.body, options)
  end

  alias_method :parsed_response, :decoded_response

  def parse(json, options={})
    MultiJson.load(json, options)
  end

  def metadata
    decoded_response['metadata']
  end

  def entity
    decoded_response['entity']
  end

  def admin_headers
    unless @admin_headers
      user = User.make_unsaved
      @admin_headers = headers_for(user, scopes: %w[cloud_controller.admin])
    end
    @admin_headers
  end

  def admin_read_only_headers
    unless @admin_read_only_headers
      user = User.make_unsaved
      @admin_read_only_headers = headers_for(user, scopes: %w[cloud_controller.admin_read_only])
    end
    @admin_read_only_headers
  end

  def global_auditor_headers
    unless @global_auditor_headers
      user = User.make_unsaved
      @global_auditor_headers = headers_for(user, scopes: %w[cloud_controller.global_auditor])
    end
    @global_auditor_headers
  end

  def build_state_updater_headers
    unless @build_state_updater_headers
      user = User.make_unsaved
      @build_state_updater_headers = headers_for(user, scopes: %w[cloud_controller.write cloud_controller.update_build_state])
    end
    @build_state_updater_headers
  end
end
