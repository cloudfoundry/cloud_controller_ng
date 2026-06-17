require 'delayed_job'
require_relative '../../../../lib/delayed_job_plugins/before_enqueue_hook'

RSpec.describe BeforeEnqueueHook do
  it 'is registered in Delayed::Worker.plugins' do
    expect(Delayed::Worker.plugins).to include(BeforeEnqueueHook)
  end

  it 'does not register duplicate entries when loaded multiple times' do
    count_before = Delayed::Worker.plugins.count(BeforeEnqueueHook)
    load File.expand_path('../../../../lib/delayed_job_plugins/before_enqueue_hook.rb', __dir__)
    count_after = Delayed::Worker.plugins.count(BeforeEnqueueHook)

    expect(count_after).to eq(count_before)
  end
end
