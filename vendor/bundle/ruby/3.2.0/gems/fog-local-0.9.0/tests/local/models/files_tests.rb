Shindo.tests('Storage[:local] | files', ["local"]) do

  pending if Fog.mocking?

  before do
    @options = { :local_root => Dir.mktmpdir('fog-tests') }
  end

  after do
    FileUtils.remove_entry_secure(@options[:local_root]) if File.directory?(@options[:local_root])
  end

  tests("#is_truncated") do
    returns(false) do
      connection = Fog::Local::Storage.new(@options)
      directory = connection.directories.create(:key => 'directory')
      collection = directory.files
      collection.is_truncated
    end
  end
end
