shared_examples :full_access do
  it { is_expected.to allow_op_on_object :create, object }
  it { is_expected.to allow_op_on_object :read, object }
  it { is_expected.to allow_op_on_object :read_for_update, object }
  it { is_expected.to allow_op_on_object :update, object }
  it { is_expected.to allow_op_on_object :delete, object }
  it { is_expected.to allow_op_on_object :index, object.class }
end

shared_examples :read_only_access do
  it { is_expected.not_to allow_op_on_object :create, object }
  it { is_expected.to allow_op_on_object :read, object }
  it { is_expected.not_to allow_op_on_object :read_for_update, object }
  # update only runs if read_for_update succeeds
  it { is_expected.not_to allow_op_on_object :update, object }
  it { is_expected.not_to allow_op_on_object :delete, object }
  it { is_expected.to allow_op_on_object :index, object.class }
end

shared_examples :no_access do
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

shared_examples :admin_full_access do
  include_context :admin_setup
  it_behaves_like :full_access
end

shared_examples :admin_read_only_access do
  include_context :admin_read_only_setup
  it_behaves_like :read_only_access
end

shared_context :admin_setup do
  before do
    token = { 'scope' => [::VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE] }
    VCAP::CloudController::SecurityContext.set(user, token)
  end

  after { VCAP::CloudController::SecurityContext.clear }
end

shared_context :admin_read_only_setup do
  before do
    token = { 'scope' => [::VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_READ_ONLY_SCOPE] }
    VCAP::CloudController::SecurityContext.set(user, token)
  end

  after { VCAP::CloudController::SecurityContext.clear }
end
