Sequel.migration do
  droplet_process_type_batcher = Class.new do
    def initialize(db)
      @db               = db
      @max_batch        = 1_000
      @batched_commands = []
    end

    def add_command(command, id)
      @batched_commands << [id, command]
      flush if @batched_commands.count >= @max_batch
    end

    def flush
      if @batched_commands.count > 0
        cases            = []
        ids              = []
        id_place_holders = []

        @batched_commands.each do |c|
          cases << 'WHEN id = ? THEN ?'
          id_place_holders << '?'
          ids << c[0]
        end

        @db[<<-SQL, *@batched_commands.flatten, *ids].update
          UPDATE droplets
          SET process_types = (CASE #{cases.join(' ')} ELSE process_types END)
          WHERE id IN (#{id_place_holders.join(',')})
        SQL
      end

      @batched_commands = []
    end
  end

  up do
    transaction do
      batcher = droplet_process_type_batcher.new(self)

      self[:droplets].each do |droplet|
        begin
          MultiJson.load(droplet[:process_types])
        rescue
          command      = droplet[:process_types].nil? ? '' : droplet[:process_types][8..-3]
          json_command = MultiJson.dump({ web: command })
          batcher.add_command(json_command, droplet[:id])
        end
      end

      batcher.flush
    end
  end

  down do
    # The up is idempotent, so do nothing
  end
end
