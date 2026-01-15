RSpec.describe 'sequel_patch' do
  describe 'version' do
    it 'is not updated' do
      expect(Gem.loaded_specs['talentbox-delayed_job_sequel'].version).to eq('4.4.0'),
                                                                          'revisit monkey patch in lib/delayed_job/sequel_patch.rb'
    end
  end
end
