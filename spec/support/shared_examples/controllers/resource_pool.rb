shared_context 'resource pool' do
  before(:all) do
    num_dirs = 3
    num_unique_allowed_files_per_dir = 7
    file_duplication_factor = 2
    @max_file_size = 1098 # this is arbitrary

    @total_allowed_files =
      num_dirs * num_unique_allowed_files_per_dir * file_duplication_factor

    @dummy_descriptor = { 'sha1' => Digester.new.digest('abc'), 'size' => 1 }
    @tmpdir = Dir.mktmpdir

    @descriptors = []
    num_dirs.times do
      dirname = SecureRandom.uuid
      Dir.mkdir("#{@tmpdir}/#{dirname}")
      num_unique_allowed_files_per_dir.times do
        basename = SecureRandom.uuid
        path = "#{@tmpdir}/#{dirname}/#{basename}"
        contents = SecureRandom.uuid

        descriptor = {
            'sha1' => Digester.new.digest(contents),
            'size' => contents.length
        }
        @descriptors << descriptor

        file_duplication_factor.times do |i|
          File.open("#{path}-#{i}", 'w') do |f|
            f.write contents
          end
        end

        File.open("#{path}-not-allowed", 'w') do |f|
          f.write 'A' * @max_file_size
        end
      end
    end

    Fog.mock!
  end

  let(:resource_pool_config) do
    {
        maximum_size: @max_file_size,
        resource_directory_key: 'spec-cc-resources',
        fog_connection: {
            provider: 'AWS',
            aws_access_key_id: 'fake_aws_key_id',
            aws_secret_access_key: 'fake_secret_access_key',
        }
    }
  end

  before do
    @resource_pool = VCAP::CloudController::ResourcePool.new(
      VCAP::CloudController::Config.new(resource_pool: resource_pool_config)
    )
  end

  after(:all) do
    FileUtils.rm_rf(@tmpdir)
  end
end
