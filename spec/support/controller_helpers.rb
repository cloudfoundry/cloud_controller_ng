module ControllerHelpers
  include VCAP::CloudController

  HTTPS_ENFORCEMENT_SCENARIOS = [
    { protocol: 'http',  config_setting: nil, user: 'user',  success: true },
    { protocol: 'http',  config_setting: nil, user: 'admin', success: true },
    { protocol: 'https', config_setting: nil, user: 'user',  success: true },
    { protocol: 'https', config_setting: nil, user: 'admin', success: true },

    # Next with https_required
    { protocol: 'http',  config_setting: :https_required, user: 'user',  success: false },
    { protocol: 'http',  config_setting: :https_required, user: 'admin', success: false },
    { protocol: 'https', config_setting: :https_required, user: 'user',  success: true },
    { protocol: 'https', config_setting: :https_required, user: 'admin', success: true },

    # Finally with https_required_for_admins
    { protocol: 'http',  config_setting: :https_required_for_admins, user: 'user',  success: true },
    { protocol: 'http',  config_setting: :https_required_for_admins, user: 'admin', success: false },
    { protocol: 'https', config_setting: :https_required_for_admins, user: 'user',  success: true },
    { protocol: 'https', config_setting: :https_required_for_admins, user: 'admin', success: true }
  ].freeze

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
    FakeFrontController.new(TestConfig.config)
  end

  def admin_headers_for(user, opts={})
    headers_for(user, opts.merge(admin: true))
  end

  def headers_for(user, opts={})
    opts = { email: Sham.email,
             https: false }.merge(opts)

    headers = {}
    headers['HTTP_AUTHORIZATION'] = "bearer #{user_token(user, opts)}"
    headers['HTTP_X_FORWARDED_PROTO'] = 'https' if opts[:https]
    headers
  end

  def json_headers(headers)
    headers.merge({ 'CONTENT_TYPE' => 'application/json' })
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
    if !@admin_headers
      user = User.make
      @admin_headers = headers_for(user, scopes: %w(cloud_controller.admin))
      user.destroy
    end
    @admin_headers
  end

  def escape_query(string)
    URI.encode(string, /[<>;:, ]/)
  end
end
