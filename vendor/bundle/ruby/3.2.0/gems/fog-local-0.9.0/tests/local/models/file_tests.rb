Shindo.tests('Storage[:local] | file', ["local"]) do

  pending if Fog.mocking?

  before do
    @options = { :local_root => Dir.mktmpdir('fog-tests') }
  end

  after do
    FileUtils.remove_entry_secure @options[:local_root]
  end

  tests('#public_url') do
    tests('when connection has an endpoint').
      returns('http://example.com/files/directory/file.txt') do
        @options[:endpoint] = 'http://example.com/files'

        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'directory')
        file = directory.files.new(:key => 'file.txt')

        file.public_url
      end

    tests('when connection has no endpoint').
      returns(nil) do
        @options[:endpoint] = nil

        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'directory')
        file = directory.files.new(:key => 'file.txt')

        file.public_url
      end

    tests('when file path has escapable characters').
      returns('http://example.com/files/my%20directory/my%20file.txt') do
        @options[:endpoint] = 'http://example.com/files'

        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'my directory')
        file = directory.files.new(:key => 'my file.txt')

        file.public_url
      end

    tests('when key has safe characters').
      returns('http://example.com/files/my/directory/my/file.txt') do
        @options[:endpoint] = 'http://example.com/files'

        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'my/directory')
        file = directory.files.new(:key => 'my/file.txt')

        file.public_url
      end
  end

  tests('#save') do
    tests('creates non-existent subdirs') do
      returns(true) do
        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'path1')
        file = directory.files.new(:key => 'path2/file.rb', :body => "my contents")
        file.save
        File.exist?(@options[:local_root] + "/path1/path2/file.rb")
      end
    end

    tests('with tempfile').returns('tempfile') do
      connection = Fog::Local::Storage.new(@options)
      directory = connection.directories.create(:key => 'directory')

      tempfile = Tempfile.new(['file', '.txt'])
      tempfile.write('tempfile')
      tempfile.rewind

      tempfile.instance_eval do
        def read
          raise 'must not be read'
        end
      end
      file = directory.files.new(:key => 'tempfile.txt', :body => tempfile)
      file.save
      tempfile.close
      tempfile.unlink
      directory.files.get('tempfile.txt').body
    end
  end

  tests('#destroy') do
    # - removes dir if it contains no files
    # - keeps dir if it contains non-hidden files
    # - keeps dir if it contains hidden files
    # - stays in the same directory

    tests('removes enclosing dir if it is empty') do
      returns(false) do
        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'path1')

        file = directory.files.new(:key => 'path2/file.rb', :body => "my contents")
        file.save
        file.destroy

        File.exist?(@options[:local_root] + "/path1/path2")
      end
    end

    tests('keeps enclosing dir if it is not empty') do
      returns(true) do
        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'path1')

        file = directory.files.new(:key => 'path2/file.rb', :body => "my contents")
        file.save

        file = directory.files.new(:key => 'path2/file2.rb', :body => "my contents")
        file.save
        file.destroy

        File.exist?(@options[:local_root] + "/path1/path2")
      end
    end

    tests('keeps enclosing dir if contains only hidden files') do
      returns(true) do
        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'path1')

        file = directory.files.new(:key => 'path2/.file.rb', :body => "my contents")
        file.save

        file = directory.files.new(:key => 'path2/.file2.rb', :body => "my contents")
        file.save
        file.destroy

        File.exist?(@options[:local_root] + "/path1/path2")
      end
    end

    tests('it stays in the same directory') do
      returns(Dir.pwd) do
        connection = Fog::Local::Storage.new(@options)
        directory = connection.directories.new(:key => 'path1')

        file = directory.files.new(:key => 'path2/file2.rb', :body => "my contents")
        file.save
        file.destroy

        Dir.pwd
      end
    end
  end
end
