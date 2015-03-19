module VCAP::CloudController
  shared_examples 'a stager' do
    it 'defines #stage_app' do
      expect(subject).to respond_to(:stage_app)
      expect { subject.stage_app(:extra_arg) }.to raise_error(ArgumentError, 'wrong number of arguments (1 for 0)')
    end

    it 'defines #stage_packages' do
      expect(subject).to respond_to(:stage_package)
      expect { subject.stage_package }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 6)')
    end

    it 'defines #staging_complete' do
      expect(subject).to respond_to(:staging_complete)
      expect { subject.staging_complete }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')
    end
  end
end
