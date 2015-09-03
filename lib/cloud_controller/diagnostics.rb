module VCAP::CloudController
  class Diagnostics
    def collect(output_directory, updater)
      data = {
        time: Time.now.utc,
        threads: thread_data,
        varz: varz_data(updater)
      }

      FileUtils.mkdir_p(output_directory)

      output_file = File.join(output_directory, output_file_name)
      File.open(output_file, 'w') do |diag_file|
        diag_file.write(MultiJson.dump(data, pretty: true))
      end

      output_file
    end

    def request_received(request)
      Thread.current[:current_request] = request_info(request)
    end

    def request_complete
      Thread.current[:current_request] = nil
    end

    private

    def request_info(request)
      {
        start_time: Time.now.utc.to_f,
        request_id: ::VCAP::Request.current_id,
        request_method: request.request_method,
        request_uri: request_uri(request)
      }
    end

    def request_uri(request)
      return request.path if request.query_string.empty?
      "#{request.path}?#{request.query_string}"
    end

    def thread_data
      Thread.list.map do |thread|
        {
          object_id: thread.object_id,
          alive: thread.alive?,
          status: thread.status,
          backtrace: thread.backtrace,
          request: thread[:current_request]
        }
      end
    end

    def varz_data(updater)
      updater.update!
      ::VCAP::Component.varz.synchronize { VCAP::Component.varz.clone }
    end

    def output_file_name
      Time.now.utc.strftime("diag-#{Process.pid}-%Y%m%d-%H:%M:%S.%L.json")
    end
  end
end
