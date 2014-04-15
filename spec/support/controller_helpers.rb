require File.expand_path("../controller_helpers/nginx_upload", __FILE__)

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

  def app
    token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
    klass = Class.new(VCAP::CloudController::Controller)
    klass.use(NginxUpload)
    klass.new(config, token_decoder)
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

  shared_examples "return a vcap rest encoded object" do
    it "should return a metadata hash in the response" do
      metadata.should_not be_nil
      metadata.should be_a_kind_of(Hash)
    end

    it "should return an id in the metadata" do
      metadata["guid"].should_not be_nil
      # used to check if the id was an integer here, but now users
      # use uaa based ids, which are strings.
    end

    it "should return a url in the metadata" do
      metadata["url"].should_not be_nil
      metadata["url"].should be_a_kind_of(String)
    end

    it "should return an entity hash in the response" do
      entity.should_not be_nil
      entity.should be_a_kind_of(Hash)
    end
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
