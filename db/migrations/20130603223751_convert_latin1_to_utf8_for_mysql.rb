Sequel.migration do
  up do
    if self.class.name.match /mysql/i
      run 'ALTER DATABASE DEFAULT CHARACTER SET utf8;'
      tables.each { |table| run "ALTER TABLE `#{table}` CONVERT TO CHARACTER SET utf8;" }
    end
  end
end
