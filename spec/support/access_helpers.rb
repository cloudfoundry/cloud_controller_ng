module AccessHelpers
  shared_examples :full_access do
    it { should allow_op_on_object :create, object }
    it { should allow_op_on_object :read, object }
    it { should allow_op_on_object :update, object }
    it { should allow_op_on_object :delete, object }
    it { should allow_op_on_object :index, object.class }
  end

  shared_examples :read_only do
    it { should_not allow_op_on_object :create, object }
    it { should allow_op_on_object :read, object }
    it { should_not allow_op_on_object :update, object }
    it { should_not allow_op_on_object :delete, object }
    it { should allow_op_on_object :index, object.class }
  end

  shared_examples :no_access do
    it { should_not allow_op_on_object :create, object }
    it { should_not allow_op_on_object :read, object }
    it { should_not allow_op_on_object :update, object }
    it { should_not allow_op_on_object :delete, object }
    #it { should_not allow_op_on_object :index, object.class }
    # backward compatibility:
    # :index is not tested here because some subclasses of BaseAccess
    # override the default behavior of always allowing access to :index
  end


  shared_examples :admin_full_access do
    include_context :admin_setup
    it_behaves_like :full_access
  end

  shared_context :admin_setup do
    subject { described_class.new(double(:context, user: nil, roles: double(:roles, :admin? => true))) }
  end

  shared_context :logged_out_setup do
    subject { described_class.new(double(:context, user: nil, roles: double(:roles, :admin? => false, :none? => true, :present? => false)))}
  end
end
