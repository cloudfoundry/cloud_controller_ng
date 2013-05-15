RSpec.configure do |config|
  config.before(:each, :skip_sqlite => true) do
    if $spec_env.db.database_type == :sqlite
      pending "This test is not valid for SQLite"
    end
  end
  config.before(:each, :skip_mysql => true) do
    if $spec_env.db.database_type == :mysql
      pending "This test is not valid for Mysql"
    end
  end
end
