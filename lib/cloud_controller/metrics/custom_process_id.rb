# Storing the metrics of several worker processes on cc-worker VMs in a DirectFileStore residing in a single directory
# did not work because the different processes are isolated by bpm and several processes used the same pid within their container.
# This pid is used for the filename and resulted in corrupted data because several processes were writing data to the same files.
# Local workers are prefixed to avoid API PID collisions; generic workers retain their existing numeric identities.
# shortcut: legacy local files are reset in BOSH pre-start; manual code upgrades need a reset with writers stopped.

module CustomProcessId
  def process_id
    index = ENV.fetch('INDEX', nil)
    return Process.pid unless index

    # shortcut: other INDEX-based roles keep numeric IDs; namespace them if they share API metric storage.
    ENV.fetch('PROCESS_TYPE', nil) == 'puma_worker' ? "index-#{index.to_i}" : index.to_i
  end
end

module Prometheus
  module Client
    module DataStores
      class DirectFileStore
        class MetricStore
          prepend CustomProcessId
        end
      end
    end
  end
end
