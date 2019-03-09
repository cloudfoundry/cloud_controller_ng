RSpec.shared_examples_for 'a lifecycle protocol' do
  let(:process) { double(:process) }
  let(:staging_details) { double(:staging_details) }
  let(:config) { instance_double(VCAP::CloudController::Config) }

  it 'provides lifecycle data' do
    lifecycle_data = lifecycle_protocol.lifecycle_data(staging_details)
    expect(lifecycle_data).to be_a(Hash)
  end

  it 'provides a staging action builder' do
    expect { lifecycle_protocol.staging_action_builder(config, staging_details) }.not_to raise_error
  end
end
