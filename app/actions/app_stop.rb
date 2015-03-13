module VCAP::CloudController
  class AppStop
    def stop(app)
      app.db.transaction do
        app.update(desired_state: 'STOPPED')

        # this will force a query, may want to eager load processes in
        # AppFetcher
        app.processes.each do |process|
          process.update({
            state: 'STOPPED',
          })
        end
      end
    end
  end
end
