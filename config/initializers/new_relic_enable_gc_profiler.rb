require 'newrelic_rpm'

module CCInitializers
  def self.new_relic_enable_gc_profiler(_)
    # NewRelic agent's CoreGCProfiler will clear GC stats
    GC::Profiler.enable
  end
end
