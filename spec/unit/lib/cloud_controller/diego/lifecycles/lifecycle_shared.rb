RSpec.shared_examples_for 'a lifecycle' do
  let(:build) { VCAP::CloudController::BuildModel.make }

  it 'creates a lifecycle data model' do
    expect do
      subject.create_lifecycle_data_model(build)
    end.not_to raise_error
  end

  it 'provides staging environment variables' do
    expect(subject.staging_environment_variables).to be_a(Hash)
  end

  it 'provides a staging message' do
    expect(subject.staging_message).to be_a(VCAP::CloudController::BuildCreateMessage)
  end

  it 'provides validations' do
    expect(subject.valid?).to be_in([true, false])
    expect(subject.errors).to be_a(Enumerable)
  end

  it 'provides a lifecycle type' do
    expect(subject.type).to be_a(String)
  end
end
