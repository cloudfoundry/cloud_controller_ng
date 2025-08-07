# frozen_string_literal: true

Sequel::Database.register_extension(:request_query_metrics) do |db|
  mod = Module.new do
    private

    def log_duration(duration, message)
      VCAP::Request.record_db_query((duration * 1_000_000).round)

      super
    end
  end

  db.singleton_class.prepend(mod)
end
