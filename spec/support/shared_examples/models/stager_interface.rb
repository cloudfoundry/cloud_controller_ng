module VCAP::CloudController
  shared_examples 'a stager' do
    it 'defines #stage' do
      expect(subject).to respond_to(:stage)
    end

    it 'defines #stop_stage' do
      expect(subject).to respond_to(:stop_stage)
    end

    it 'defines #staging_complete, expecting 2 arguments' do
      expect(subject).to respond_to(:staging_complete)
      expect(subject.method(:staging_complete).arity).to eq(2)
    end
  end
end
