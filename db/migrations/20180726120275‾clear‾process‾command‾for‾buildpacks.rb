Sequel.migration do
  up do
    # this migration has been blanked out because it did not take into account
    # process.metadata['command']

    # 20180813221823_clear_process_command_and_metadata_command.rb is a
    # re-implementation of this migration that will work for environments that have
    # run this migration AND environments that have not run this migration
  end

  down do
  end
end
