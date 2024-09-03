RSpec.describe 'delayed_job' do
  describe 'version' do
    it 'is not updated' do
      expect(Gem.loaded_specs['delayed_job'].version).to eq('4.1.11'),
                                                         'revisit monkey patch in lib/delayed_job/quit_trap.rb + review the changes related to lib/delayed_job/threaded_worker.rb'
    end
  end
end
