require 'support/controller_helpers'

module AcceptanceHelpers
  include ControllerHelpers

  def setup_uaa_stubs_to_add_new_client
    # stub uaa token request
    stub_request(:post, 'http://cc_service_broker_client:some-sekret@localhost:8080/uaa/oauth/token').to_return(
      status:  200,
      body:    { token_type: 'token-type', access_token: 'access-token' }.to_json,
      headers: { 'content-type' => 'application/json' })

    # stub uaa client search request
    stub_request(:get, 'http://localhost:8080/uaa/oauth/clients/dash-id').to_return(status: 404)

    # stub uaa client create request
    stub_request(:post, 'http://localhost:8080/uaa/oauth/clients/tx/modify').to_return(
      status:  201,
      body:    { id: 'some-id', client_id: 'dash-id' }.to_json,
      headers: { 'content-type' => 'application/json' })
  end
end
