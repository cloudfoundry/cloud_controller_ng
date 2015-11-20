shared_examples_for 'a lifecycle' do
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
end
