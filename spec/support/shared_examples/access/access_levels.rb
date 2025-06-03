RSpec.shared_examples 'full access' do
  it { is_expected.to allow_op_on_object :create, object }
  it { is_expected.to allow_op_on_object :read, object }
  it { is_expected.to allow_op_on_object :read_for_update, object }
  it { is_expected.to allow_op_on_object :update, object }
  it { is_expected.to allow_op_on_object :delete, object }
  it { is_expected.to allow_op_on_object :index, object.class }
end

RSpec.shared_examples 'read only access' do
  it { is_expected.not_to allow_op_on_object :create, object }
  it { is_expected.to allow_op_on_object :read, object }
  it { is_expected.not_to allow_op_on_object :read_for_update, object }
  # update only runs if read_for_update succeeds
  it { is_expected.not_to allow_op_on_object :update, object }
  it { is_expected.not_to allow_op_on_object :delete, object }
  it { is_expected.to allow_op_on_object :index, object.class }
end

RSpec.shared_examples 'no access' do
  it { is_expected.not_to allow_op_on_object :create, object }
  it { is_expected.not_to allow_op_on_object :read, object }
  it { is_expected.not_to allow_op_on_object :read_for_update, object }
  it { is_expected.not_to allow_op_on_object :update, object }
  it { is_expected.not_to allow_op_on_object :delete, object }
  # it { should_not allow_op_on_object :index, object.class }
  # backward compatibility:
  # :index is not tested here because some subclasses of BaseAccess
  # override the default behavior of always allowing access to :index
end

RSpec.shared_examples 'admin full access' do
  include_context 'admin setup'
  it_behaves_like 'full access'
end

RSpec.shared_examples 'admin read only access' do
  include_context 'admin read only setup'
  it_behaves_like 'read only access'
end

RSpec.shared_examples 'global auditor access' do
  include_context 'global auditor setup'
  it_behaves_like 'read only access'
end

RSpec.shared_context 'admin setup' do
  before do
    token = { 'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] }
    VCAP::CloudController::SecurityContext.set(user, token)
  end

  after { VCAP::CloudController::SecurityContext.clear }
end

RSpec.shared_context 'global auditor setup' do
  before do
    token = { 'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_GLOBAL_AUDITOR] }
    VCAP::CloudController::SecurityContext.set(user, token)
  end

  after { VCAP::CloudController::SecurityContext.clear }
end

RSpec.shared_context 'admin read only setup' do
  before do
    token = { 'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE] }
    VCAP::CloudController::SecurityContext.set(user, token)
  end

  after { VCAP::CloudController::SecurityContext.clear }
end
