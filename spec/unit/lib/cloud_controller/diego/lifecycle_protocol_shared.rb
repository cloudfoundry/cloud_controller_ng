RSpec.shared_examples_for 'a lifecycle protocol' do
  let(:process) { double(:process) }
  let(:staging_details) { double(:staging_details) }
  let(:config) { instance_double(VCAP::CloudController::Config) }

  it 'provides lifecycle data' do
    lifecycle_data = lifecycle_protocol.lifecycle_data(staging_details)
    expect(lifecycle_data).to be_a(Hash)
  end

  it 'provides a desired app message' do
    desired_app_message = lifecycle_protocol.desired_app_message(process)
    expect(desired_app_message).to be_a(Hash)
    expect(desired_app_message).to have_key('start_command')
  end

  it 'provides a staging action builder' do
    expect { lifecycle_protocol.staging_action_builder(config, staging_details) }.not_to raise_error
  end
end
