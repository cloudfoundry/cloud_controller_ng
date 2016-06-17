RSpec.shared_examples_for 'a lifecycle' do
  let(:droplet) { VCAP::CloudController::DropletModel.make }

  it 'creates a lifecycle data model' do
    expect {
      subject.create_lifecycle_data_model(droplet)
    }.not_to raise_error
  end

  it 'provides staging environment variables' do
    expect(subject.staging_environment_variables).to be_a(Hash)
  end

  it 'provides pre-known receipt information' do
    expect(subject.pre_known_receipt_information).to be_a(Hash)
  end

  it 'provides a staging message' do
    expect(subject.staging_message).to be_a(VCAP::CloudController::DropletCreateMessage)
  end

  it 'provides validations' do
    expect(subject.valid?).to be_in([true, false])
    expect(subject.errors).to be_a(Enumerable)
  end

  it 'provides a lifecycle type' do
    expect(subject.type).to be_a(String)
  end
end
