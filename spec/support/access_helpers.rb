module AccessHelpers
  shared_examples :full_access do
    it { should be_able_to :create, object }
    it { should be_able_to :read, object }
    it { should be_able_to :update, object }
    it { should be_able_to :delete, object }
  end

  shared_examples :read_only do
    it { should_not be_able_to :create, object }
    it { should be_able_to :read, object }
    it { should_not be_able_to :update, object }
    it { should_not be_able_to :delete, object }
  end

  shared_examples :no_access do
    it { should_not be_able_to :create, object }
    it { should_not be_able_to :read, object }
    it { should_not be_able_to :update, object }
    it { should_not be_able_to :delete, object }
  end

  shared_examples :read_error do
    it { should_not be_able_to :create, object }
    it { should_not be_able_to :update, object }
    it { should_not be_able_to :delete, object }
    it 'raises missing required scope error' do
      begin
        should_not be_able_to :read, object
      rescue VCAP::Errors::MissingRequiredScopeError => e
        expect(e.is_a? VCAP::Errors::MissingRequiredScopeError).to eq(true)
      end
    end

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
