module DefaultConfig
  def self.for_specs
    db_connection_string = if ENV["DB_CONNECTION"]
      "#{ENV["DB_CONNECTION"]}/cc_test_#{ENV["TEST_ENV_NUMBER"]}"
    else
      "sqlite:///tmp/cc_test#{ENV["TEST_ENV_NUMBER"]}.db"
    end

    config_file = File.expand_path("../../config/cloud_controller.yml", File.dirname(__FILE__))
    config_hash = VCAP::CloudController::Config.from_file(config_file)

    config_hash.update(
        :nginx => {:use_nginx => true},
        :resource_pool => {
            :resource_directory_key => "spec-cc-resources",
            :fog_connection => {
                :provider => "AWS",
                :aws_access_key_id => "fake_aws_key_id",
                :aws_secret_access_key => "fake_secret_access_key",
            },
        },
        :packages => {
            :app_package_directory_key => "cc-packages",
            :fog_connection => {
                :provider => "AWS",
                :aws_access_key_id => "fake_aws_key_id",
                :aws_secret_access_key => "fake_secret_access_key",
            },
        },
        :droplets => {
            :droplet_directory_key => "cc-droplets",
            :fog_connection => {
                :provider => "AWS",
                :aws_access_key_id => "fake_aws_key_id",
                :aws_secret_access_key => "fake_secret_access_key",
            },
        },

        :db => {
            :log_level => "debug",
            :database => db_connection_string,
            :pool_timeout => 10
        }
    )

    config_hash
  end
end
