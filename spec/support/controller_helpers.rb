module ControllerHelpers
  include VCAP::CloudController

  HTTPS_ENFORCEMENT_SCENARIOS = [
    {:protocol => "http",  :config_setting => nil, :user => "user",  :success => true},
    {:protocol => "http",  :config_setting => nil, :user => "admin", :success => true},
    {:protocol => "https", :config_setting => nil, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => nil, :user => "admin", :success => true},

    # Next with https_required
    {:protocol => "http",  :config_setting => :https_required, :user => "user",  :success => false},
    {:protocol => "http",  :config_setting => :https_required, :user => "admin", :success => false},
    {:protocol => "https", :config_setting => :https_required, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => :https_required, :user => "admin", :success => true},

    # Finally with https_required_for_admins
    {:protocol => "http",  :config_setting => :https_required_for_admins, :user => "user",  :success => true},
    {:protocol => "http",  :config_setting => :https_required_for_admins, :user => "admin", :success => false},
    {:protocol => "https", :config_setting => :https_required_for_admins, :user => "user",  :success => true},
    {:protocol => "https", :config_setting => :https_required_for_admins, :user => "admin", :success => true}
  ]

  def self.description_for_inline_depth(depth, pagination = 50)
    if depth
      "?inline-relations-depth=#{depth}&results-per-page=#{pagination}"
    else
      ""
    end
  end

  def query_params_for_inline_depth(depth, pagination = 50)
    if depth
      {"inline-relations-depth" => depth, "results-per-page" => pagination}
    else
      {"results-per-page" => pagination}
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
    FakeFrontController.new(config)
  end

  def headers_for(user, opts = {})
    opts = { :email => Sham.email,
             :https => false}.merge(opts)

    headers = {}
    token_coder = CF::UAA::TokenCoder.new(:audience_ids => config[:uaa][:resource_id],
                                          :skey => config[:uaa][:symmetric_secret],
                                          :pkey => nil)

    scopes = opts[:scopes]
    if scopes.nil?
      scopes = opts[:admin_scope] ? %w[cloud_controller.admin] : %w[cloud_controller.read cloud_controller.write]
    end

    if user || opts[:admin_scope]
      user_token = token_coder.encode(
        :user_id => user ? user.guid : (rand * 1_000_000_000).ceil,
        :email => opts[:email],
        :scope => scopes
      )

      headers["HTTP_AUTHORIZATION"] = "bearer #{user_token}"
    end

    headers["HTTP_X_FORWARDED_PROTO"] = "https" if opts[:https]
    headers
  end

  def json_headers(headers)
    headers.merge({ "CONTENT_TYPE" => "application/json"})
  end

  def decoded_response(options={})
    parse(last_response.body, options)
  end

  def parse(json, options={})
    Yajl::Parser.parse(json, options)
  end

  def metadata
    decoded_response["metadata"]
  end

  def entity
    decoded_response["entity"]
  end

  def admin_user
    @admin_user ||= VCAP::CloudController::User.make(:admin => true)
  end

  def admin_headers
    @admin_headers ||= headers_for(admin_user, :admin_scope => true)
  end

  def resource_match_request(verb, path, matches, non_matches)
    user = User.make(:admin => true, :active => true)
    req = Yajl::Encoder.encode(matches + non_matches)
    send(verb, path, req, json_headers(headers_for(user)))
    last_response.status.should == 200
    resp = Yajl::Parser.parse(last_response.body)
    resp.should == matches
  end
end
