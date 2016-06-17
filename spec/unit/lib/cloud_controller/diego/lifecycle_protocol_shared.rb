RSpec.shared_examples_for 'a lifecycle protocol' do
  let(:app) { double(:app) }

  it 'provides lifecycle data' do
    type, lifecycle_data = lifecycle_protocol.lifecycle_data(app)
    expect(type).to be_a(String)
    expect(lifecycle_data).to be_a(Hash)
  end

  it 'provides a desired app message' do
    desired_app_message = lifecycle_protocol.desired_app_message(app)
    expect(desired_app_message).to be_a(Hash)
    expect(desired_app_message).to have_key('start_command')
  end
end

RSpec.shared_examples_for 'a v3 lifecycle protocol' do
  let(:package) { double(:package) }
  let(:staging_details) { double(:staging_details) }

  it 'provides lifecycle data' do
    type, lifecycle_data = lifecycle_protocol.lifecycle_data(package, staging_details)
    expect(type).to be_a(String)
    expect(lifecycle_data).to be_a(Hash)
  end
end
