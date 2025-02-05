# Storing the metrics of several worker processes on cc-worker VMs in a DirectFileStore residing in a single directory
# did not work because the different processes are isolated by bpm and several processes used the same pid within their container.
# This pid is used for the filename and resulted in corrupted data because several processes were writing data to the same files.
# When requiring this file, the process_id method of the MetricStore will be overridden to first check for `INDEX` in
# env variables before returning the actual pid. The `INDEX` is provided for cc-worker processes.

module CustomProcessId
  def process_id
    ENV.fetch('INDEX', Process.pid).to_i
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
