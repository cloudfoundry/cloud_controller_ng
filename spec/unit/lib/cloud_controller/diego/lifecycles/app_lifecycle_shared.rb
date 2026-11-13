RSpec.shared_examples_for 'a app lifecycle' do
  let(:app) { create(:app_model) }

  it 'creates a lifecycle data model' do
    expect do
      subject.create_lifecycle_data_model(app)
    end.not_to raise_error
  end

  it 'provides validations' do
    expect(subject.valid?).to be_in([true, false])
    expect(subject.errors).to be_a(Enumerable)
  end

  it 'updates a lifecycle data model' do
    expect do
      subject.update_lifecycle_data_model(app)
    end.not_to raise_error
  end

  it 'provides a type' do
    expect(subject.type).to be_a(String)
  end
end

RSpec.shared_examples_for 'custom-stack lifecycle updates' do |lifecycle_type, buildpack_url|
  subject(:lifecycle) { described_class.new(message, app) }

  let(:app) { create(:app_model, lifecycle_type.to_sym) }
  let(:stored_stack) { 'docker://registry.example.com/team/stack:v1' }
  let(:requested_stack) { 'docker://registry.example.com/team/stack:v2' }
  let(:stored_buildpacks) { [buildpack_url] }
  let(:pinned_buildpack) { create(:buildpack, name: 'default-stack-buildpack', stack: VCAP::CloudController::Stack.default.name, lifecycle: lifecycle_type) }
  let(:message) { VCAP::CloudController::AppUpdateMessage.new(lifecycle: { type: lifecycle_type, data: { stack: requested_stack } }) }

  before do
    create(:feature_flag, name: 'diego_custom_stacks', enabled: true)
    app.lifecycle_data.update(stack: stored_stack, buildpacks: stored_buildpacks)
  end

  it 'validates and retains the configured custom buildpacks' do
    expect(lifecycle).to be_valid
    lifecycle.update_lifecycle_data_model(app)

    expect(app.lifecycle_data.reload).to have_attributes(stack: requested_stack, buildpacks: stored_buildpacks)
  end

  context 'with a retained stack-pinned admin buildpack' do
    let(:stored_stack) { VCAP::CloudController::Stack.default.name }
    let(:stored_buildpacks) { [pinned_buildpack.name] }

    it 'rejects the incompatible buildpack instead of treating the request as auto-detection' do
      expect(lifecycle).not_to be_valid
      expect(lifecycle.errors[:buildpack]).to include('"default-stack-buildpack" must be an existing admin buildpack or a valid git URI')
    end
  end

  context 'when only buildpacks are updated' do
    let(:message) { VCAP::CloudController::AppUpdateMessage.new(lifecycle: { type: lifecycle_type, data: { buildpacks: [pinned_buildpack.name] } }) }

    it 'validates against the retained custom stack, not the default stack' do
      expect(lifecycle).not_to be_valid
      expect(lifecycle.errors[:buildpack]).to include('"default-stack-buildpack" must be an existing admin buildpack or a valid git URI')
    end
  end

  context 'when resetting the stack to null' do
    let(:requested_stack) { nil }

    it 'keeps the existing stack-reset behavior' do
      expect(lifecycle).to be_valid
      lifecycle.update_lifecycle_data_model(app)

      expect(app.lifecycle_data.reload).to have_attributes(stack: nil, buildpacks: stored_buildpacks)
    end
  end
end
