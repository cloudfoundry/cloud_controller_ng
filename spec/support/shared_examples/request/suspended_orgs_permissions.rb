RSpec.shared_examples 'Permissions when organization is suspended' do
  before do
    org.status = 'suspended'
    org.save
  end

  it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
    let(:expected_codes_and_responses) do
      expected_codes ||
      Hash.new(code: 422).tap do |h|
        h['admin'] = { code: 202 }
        h['admin_read_only'] = { code: 403 }
        h['global_auditor'] = { code: 403 }
        h['space_developer'] = { code: 403 }
        h['space_auditor'] = { code: 403 }
        h['space_manager'] = { code: 403 }
        h['org_manager'] = { code: 403 }
      end
    end
  end
end
