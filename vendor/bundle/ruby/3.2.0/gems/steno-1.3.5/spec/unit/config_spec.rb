require 'fileutils'
require 'yaml'

require 'spec_helper'

describe Steno::Config do
  if Steno::Sink::WINDOWS
    describe '.from_hash' do
      before do
        @log_path = 'some_file'

        @mock_sink_file = double('sink')
        expect(@mock_sink_file).to receive(:codec=)
        expect(Steno::Sink::IO).to receive(:for_file).with(@log_path,
                                                           max_retries: 5)
                                                     .and_return(@mock_sink_file)

        @mock_sink_eventlog = double('sink')
        expect(@mock_sink_eventlog).to receive(:codec=)
        expect(@mock_sink_eventlog).to receive(:open).with('test')
        expect(Steno::Sink::Eventlog).to receive(:instance).twice
                                                           .and_return(@mock_sink_eventlog)
      end

      after do
        @config = Steno::Config.from_hash(@hash)

        expect(@config.default_log_level).to eq(:debug2)
        expect(@config.context.class).to eq(Steno::Context::Null)
        expect(@config.codec.class).to eq(Steno::Codec::Json)

        expect(@config.sinks.size).to eq(2)
        expect(@config.sinks).to contain_exactly(@mock_sink_file, @mock_sink_eventlog)
      end

      it 'works for symbolized keys' do
        @hash = {
          file: @log_path,
          level: 'debug2',
          default_log_level: 'warn',
          eventlog: 'test',
          max_retries: 5
        }
      end

      it 'works for non-symbolized keys' do
        @hash = {
          'file' => @log_path,
          'level' => 'debug2',
          'default_log_level' => 'warn',
          'eventlog' => 'test',
          'max_retries' => 5
        }
      end
    end
  else
    describe '.from_hash' do
      before do
        @log_path = 'some_file'

        @mock_sink_file = double('sink')
        allow(@mock_sink_file).to receive(:codec=)
        expect(Steno::Sink::IO).to receive(:for_file).with(@log_path,
                                                           max_retries: 5)
                                                     .and_return(@mock_sink_file)

        @mock_sink_syslog = double('sink')
        expect(@mock_sink_syslog).to receive(:codec=)
        expect(@mock_sink_syslog).to receive(:open).with('test')
        expect(Steno::Sink::Syslog).to receive(:instance).twice
                                                         .and_return(@mock_sink_syslog)
      end

      after do
        @config = Steno::Config.from_hash(@hash)

        expect(@config.default_log_level).to eq(:debug2)
        expect(@config.context.class).to eq(Steno::Context::Null)
        expect(@config.codec.class).to eq(Steno::Codec::Json)

        expect(@config.sinks.size).to eq(2)
        expect(@config.sinks).to contain_exactly(@mock_sink_file, @mock_sink_syslog)
      end

      it 'works for symbolized keys' do
        @hash = {
          file: @log_path,
          level: 'debug2',
          default_log_level: 'warn',
          syslog: 'test',
          max_retries: 5
        }
      end

      it 'works for non-symbolized keys' do
        @hash = {
          'file' => @log_path,
          'level' => 'debug2',
          'default_log_level' => 'warn',
          'syslog' => 'test',
          'max_retries' => 5
        }
      end
    end
  end

  describe '.from_file' do
    before do
      @tmpdir = Dir.mktmpdir
      @config_path = File.join(@tmpdir, 'config.yml')
      @log_path = File.join(@tmpdir, 'test.log')
    end

    after do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'returns Steno::Config instance with sane defaults' do
      write_config(@config_path, {})

      config = Steno::Config.from_file(@config_path)

      expect(config.sinks.size).to eq(1)
      expect(config.sinks[0].class).to eq(Steno::Sink::IO)

      expect(config.default_log_level).to eq(:info)

      expect(config.context.class).to eq(Steno::Context::Null)

      expect(config.codec.class).to eq(Steno::Codec::Json)
      expect(config.codec.iso8601_timestamps?).to eq(false)
    end

    it 'configures json codec with readable dates if iso8601_timestamps is true' do
      write_config(@config_path, { 'iso8601_timestamps' => 'true' })
      config = Steno::Config.from_file(@config_path)
      expect(config.codec.class).to eq(Steno::Codec::Json)
      expect(config.codec.iso8601_timestamps?).to eq(true)
    end

    it 'sets the default_log_level if a key with the same name is supplied' do
      write_config(@config_path, { 'level' => 'debug2' })
      expect(Steno::Config.from_file(@config_path).default_log_level).to eq(:debug2)

      write_config(@config_path, { 'default_log_level' => 'debug2' })
      expect(Steno::Config.from_file(@config_path).default_log_level).to eq(:debug2)
    end

    it "reads the 'level' key if both default_log_level and level are spscified" do
      write_config(@config_path, { 'level' => 'debug2',
                                   'default_log_level' => 'warn' })
      expect(Steno::Config.from_file(@config_path).default_log_level).to eq(:debug2)
    end

    it "adds a file sink if the 'file' key is specified" do
      write_config(@config_path, { 'file' => @log_path, 'max_retries' => 2 })
      mock_sink = double('sink')
      expect(mock_sink).to receive(:codec=)

      expect(Steno::Sink::IO).to receive(:for_file)
        .with(@log_path, max_retries: 2).and_return(mock_sink)
      config = Steno::Config.from_file(@config_path)
      expect(config.sinks.size).to eq(1)
      expect(config.sinks[0]).to eq(mock_sink)
    end

    if Steno::Sink::WINDOWS
      it "adds a event sink if the 'eventlog' key is specified" do
        write_config(@config_path, { 'eventlog' => 'test' })
        mock_sink = double('sink')
        expect(mock_sink).to receive(:open).with('test')
        expect(mock_sink).to receive(:codec=)

        expect(Steno::Sink::Eventlog).to receive(:instance).twice.and_return(mock_sink)

        config = Steno::Config.from_file(@config_path)
        expect(config.sinks.size).to eq(1)
        expect(config.sinks[0]).to eq(mock_sink)
      end
    else
      it "adds a syslog sink if the 'syslog' key is specified" do
        write_config(@config_path, { 'syslog' => 'test' })
        mock_sink = double('sink')
        expect(mock_sink).to receive(:open).with('test')
        expect(mock_sink).to receive(:codec=)

        expect(Steno::Sink::Syslog).to receive(:instance).twice.and_return(mock_sink)

        config = Steno::Config.from_file(@config_path)
        expect(config.sinks.size).to eq(1)
        expect(config.sinks[0]).to eq(mock_sink)
      end
    end

    it 'adds an io sink to stdout if no sinks are explicitly specified in the config file' do
      write_config(@config_path, {})
      mock_sink = double('sink')
      expect(mock_sink).to receive(:codec=)

      expect(Steno::Sink::IO).to receive(:new).with(STDOUT).and_return(mock_sink)

      config = Steno::Config.from_file(@config_path)
      expect(config.sinks.size).to eq(1)
      expect(config.sinks[0]).to eq(mock_sink)
    end

    it 'merges supplied overrides with the file based config' do
      write_config(@config_path, { 'default_log_level' => 'debug' })

      context = Steno::Context::ThreadLocal.new
      config = Steno::Config.from_file(@config_path,
                                       default_log_level: 'warn',
                                       context: context)
      expect(config.context).to eq(context)
      expect(config.default_log_level).to eq(:warn)
    end
  end

  def write_config(path, config)
    File.write(path, YAML.dump({ 'logging' => config }))
  end
end
