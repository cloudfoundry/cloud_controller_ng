shared_context 'resource pool' do
  before(:all) do
    @max_file_size = 1098 # this is arbitrary
    num_dirs = 3
    num_unique_allowed_files_per_dir = 7
    file_duplication_factor = 2

    @total_allowed_files =
      num_dirs * num_unique_allowed_files_per_dir * file_duplication_factor

    @nonexisting_descriptor = { 'sha1' => Digester.new.digest('abc'), 'size' => 1 }
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
        maximum_size: maximum_file_size,
        minimum_size: minimum_file_size,
        resource_directory_key: 'spec-cc-resources',
        fog_connection: {
            provider: 'AWS',
            aws_access_key_id: 'fake_aws_key_id',
            aws_secret_access_key: 'fake_secret_access_key',
        }
    }
  end

  let(:maximum_file_size) { @max_file_size }
  let(:minimum_file_size) { 0 }

  before do
    @resource_pool = VCAP::CloudController::ResourcePool.new(
      VCAP::CloudController::Config.new(resource_pool: resource_pool_config)
    )
    allow(VCAP::CloudController::ResourcePool).to receive(:instance).and_return(@resource_pool)
  end

  after(:all) do
    FileUtils.rm_rf(@tmpdir)
  end
end
