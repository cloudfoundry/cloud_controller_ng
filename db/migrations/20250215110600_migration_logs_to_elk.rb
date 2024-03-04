Sequel.migration do
  logger = Steno.logger('cc.db.migrations')
  up do
    100.times do
      sleep 1
      logger.info('still migrating')
    end
    logger.info('migration finished')
  end
  down do
  end
end
