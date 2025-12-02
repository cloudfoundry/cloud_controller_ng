require 'spec_helper'
if Steno::Sink::WINDOWS
  describe Steno::Sink::Eventlog do
    let(:level) do
      Steno::Logger.lookup_level(:info)
    end

    let(:record) do
      Steno::Record.new('source', level.name, 'message')
    end

    describe '#add_record' do
      it 'appends an encoded record with the correct priority' do
        eventlog = double('Win32::EventLog')
        Win32::EventLog.should_receive(:open)
                       .with('Application')
                       .and_return(eventlog)

        sink = Steno::Sink::Eventlog.instance
        sink.open

        codec = double('codec')
        codec.should_receive(:encode_record).with(record).and_return(record.message)
        sink.codec = codec

        eventlog.should_receive(:report_event).with(source: 'CloudFoundry',
                                                    event_type: Win32::EventLog::INFO_TYPE,
                                                    data: record.message)

        sink.add_record(record)
      end
    end

    describe '#flush' do
      it 'does nothing' do
        Steno::Sink::Eventlog.instance.flush
      end
    end
  end
end
