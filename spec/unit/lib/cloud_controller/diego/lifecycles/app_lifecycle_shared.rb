RSpec.shared_examples_for 'a app lifecycle' do
  let(:app) { VCAP::CloudController::AppModel.make }

  it 'creates a lifecycle data model' do
    expect {
      subject.create_lifecycle_data_model(app)
    }.not_to raise_error
  end

  it 'provides validations' do
    expect(subject.valid?).to be_in([true, false])
    expect(subject.errors).to be_a(Enumerable)
  end

  it 'updates a lifecycle data model' do
    expect {
      subject.update_lifecycle_data_model(app)
    }.not_to raise_error
  end

  it 'provides a type' do
    expect(subject.type).to be_a(String)
  end
end
