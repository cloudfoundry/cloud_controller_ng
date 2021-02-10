RSpec.shared_examples 'a successful broker delete' do
  before do
    clear_events
    delete "/v3/service_brokers/#{broker.guid}", {}, user_headers
  end

  it 'returns 204 No Content' do
    expect(last_response).to have_status_code(204)
  end

  it 'deletes the broker' do
    is_expected.to_not find_broker(broker_guid: broker.guid, with: user_headers)
  end

  it 'deletes the service offerings and plans' do
    services = VCAP::CloudController::Service.where(id: broker_services.map(&:id))
    expect(services).to have(0).items

    plans = VCAP::CloudController::ServicePlan.where(id: broker_plans.map(&:id))
    expect(plans).to have(0).items
  end

  it 'emits service and plan deletion events, and broker deletion event' do
    expect(broker_delete_events(actor, user_headers._generated_email)).to be_reported_as_events
  end

  it 'deletes the UAA clients related to this broker' do
    # see service_broker_remover.rb
    uaa_client_id = "#{broker_id}-uaa-id"
    expect(VCAP::CloudController::ServiceDashboardClient.find_client_by_uaa_id(uaa_client_id)).to be_nil

    expect(a_request(:post, 'https://uaa.service.cf.internal/oauth/clients/tx/modify').
      with(
        body: [
          {
            client_id: uaa_client_id,
            client_secret: nil,
            redirect_uri: nil,
            scope: %w(openid cloud_controller_service_permissions.read),
            authorities: ['uaa.resource'],
            authorized_grant_types: ['authorization_code'],
            action: 'delete'
          }
        ].to_json
      )).to have_been_made
  end

  def clear_events
    VCAP::CloudController::Event.dataset.destroy
  end

  def broker_delete_events(actor, email)
    [
      { type: 'audit.service.delete', actor: actor },
      { type: 'audit.service.delete', actor: actor },
      { type: 'audit.service_broker.delete', actor: email },
      { type: 'audit.service_dashboard_client.delete', actor: actor },
      { type: 'audit.service_plan.delete', actor: actor },
      { type: 'audit.service_plan.delete', actor: actor },
    ]
  end
end
