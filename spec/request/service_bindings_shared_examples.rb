# Must define:
# - api_call (lambda)
# - guid
# - update_request_body
# - binding_name
RSpec.shared_examples 'metadata update for service binding' do |audit_name|
  it 'can update labels and annotations' do
    api_call.call(admin_headers)
    expect(last_response).to have_status_code(200)
    expect(parsed_response.deep_symbolize_keys).to include(update_request_body)
  end

  it 'logs an audit event' do
    api_call.call(admin_headers)

    event = VCAP::CloudController::Event.find(type: "audit.#{audit_name}.update")
    expect(event).not_to be_nil
    expect(event.actee).to eq(binding.guid)
    expect(event.actee_name).to eq(binding_name)
    expect(event.data).to include({
      'request' => update_request_body.with_indifferent_access
    })
  end

  context 'when some labels are invalid' do
    let(:labels) { { potato: 'sweet invalid potato' } }

    it 'returns a proper failure' do
      api_call.call(admin_headers)

      expect(last_response).to have_status_code(422)
      expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
    end
  end

  context 'when some annotations are invalid' do
    let(:annotations) { { '/style' => 'sweet invalid style' } }

    it 'returns a proper failure' do
      api_call.call(admin_headers)

      expect(last_response).to have_status_code(422)
      expect(parsed_response['errors'][0]['detail']).to match(/Metadata [\w\s]+ error/)
    end
  end

  context 'when the binding does not exist' do
    let(:guid) { 'moonlight-sonata' }

    it 'returns a not found error' do
      api_call.call(admin_headers)
      expect(last_response).to have_status_code(404)
    end
  end

  context 'when the binding is being created' do
    before do
      binding.save_with_attributes_and_new_operation(
        {},
        { type: 'create', state: 'in progress', broker_provided_operation: 'some-info' }
      )
    end

    before do
      api_call.call(admin_headers)
      expect(last_response).to have_status_code(200)
      binding.reload
    end

    it 'can still update metadata' do
      expect(binding).to have_labels({ prefix: nil, key: 'potato', value: 'sweet' })
      expect(binding).to have_annotations({ prefix: nil, key: 'style', value: 'mashed' }, { prefix: nil, key: 'amount', value: 'all' })
    end

    it 'does not update last operation' do
      expect(binding.last_operation.type).to eq('create')
      expect(binding.last_operation.state).to eq('in progress')
      expect(binding.last_operation.broker_provided_operation).to eq('some-info')
    end
  end

  context 'when the binding is being deleted' do
    before do
      binding.save_with_attributes_and_new_operation(
        {},
        { type: 'delete', state: 'in progress', broker_provided_operation: 'some-info' }
      )
    end

    it 'responds with a 422' do
      api_call.call(admin_headers)
      expect(last_response).to have_status_code(422)
    end

    it 'does not update last operation' do
      api_call.call(admin_headers)
      binding.reload
      expect(binding.last_operation.type).to eq('delete')
      expect(binding.last_operation.state).to eq('in progress')
      expect(binding.last_operation.broker_provided_operation).to eq('some-info')
    end
  end
end
