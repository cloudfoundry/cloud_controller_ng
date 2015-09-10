module VCAP::CloudController
  shared_examples 'a stager' do
    it 'defines #stage' do
      expect(subject).to respond_to(:stage)
    end

    it 'defines #staging_complete' do
      expect(subject).to respond_to(:staging_complete)
      expect { subject.staging_complete }.to raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')
    end
  end
end
