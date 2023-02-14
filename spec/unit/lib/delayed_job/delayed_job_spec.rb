RSpec.describe 'delayed_job' do
  describe 'version' do
    it 'should not be updated' do
      expect(Gem.loaded_specs['delayed_job'].version).to eq('4.1.9'), 'revisit monkey patch in lib/delayed_job/quit_trap.rb'
    end
  end
end
