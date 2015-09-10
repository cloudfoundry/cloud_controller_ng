require 'spec_helper'

module VCAP::CloudController
  describe Diagnostics do
    let(:request_method) { 'GET' }
    let(:path) { '/path' }
    let(:query_string) { 'query' }
    let(:request_id) { 'request_id' }

    let(:request) do
      double('Request', {
        request_method: request_method,
        path: path,
        query_string: query_string,
      })
    end

    let(:updater) { instance_double(VCAP::CloudController::Metrics::PeriodicUpdater).tap { |u| allow(u).to receive(:update!) } }

    subject(:diagnostics) { Diagnostics.new }

    before do
      allow(EventMachine).to receive(:connection_count).and_return(17)
    end

    describe '::request_received' do
      before do
        VCAP::Request.current_id = request_id
        diagnostics.request_received(request)
      end

      def current_request
        Thread.current[:current_request]
      end

      it 'saves request info in a thread local' do
        expect(current_request).to_not be_nil
      end

      it 'saves the request info as a hash' do
        expect(current_request).to be_an_instance_of(Hash)
      end

      it 'populates the start time to now' do
        now = Time.now.utc
        Timecop.freeze now do
          expect(current_request[:start_time]).to be_within(0.01).of(now.to_f)
        end
      end

      it 'populates the request ID from VCAP::Request' do
        expect(current_request[:request_id]).to eq(request_id)
      end

      it 'populates the request method' do
        expect(current_request[:request_method]).to eq(request_method)
      end

      context 'when a query string is not present' do
        let(:query_string) { '' }

        it 'sets the request uri to the path' do
          expect(current_request[:request_uri]).to eq(path)
        end
      end

      context 'when a query string is present' do
        it 'includes the query string in the request uri' do
          expect(current_request[:request_uri]).to eq("#{path}?#{query_string}")
        end
      end
    end

    describe '::request_complete' do
      before { Thread.current[:current_request] = {} }

      it 'clears the request info from the thread local' do
        expect {
          diagnostics.request_complete
        }.to change {
          Thread.current[:current_request]
        }.from({}).to(nil)
      end
    end

    describe '::collect' do
      let(:temp_dir) { Dir.mktmpdir }
      let(:output_dir) { File.join(temp_dir, 'diagnostics') }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'creates the destination directory if needed' do
        expect(File.exist?(output_dir)).to be false
        diagnostics.collect(output_dir, updater)
        expect(File.exist?(output_dir)).to be true
      end

      it 'returns the name of the output file' do
        filename = diagnostics.collect(output_dir, updater)
        expect(filename).to_not be_nil
        expect(File.exist?(filename)).to be true
      end

      describe 'file name' do
        it 'uses a file name that includes a time stamp' do
          Timecop.freeze Time.now.utc do
            filename = diagnostics.collect(output_dir, updater)
            timestamp = Time.now.utc.strftime('%Y%m%d-%H:%M:%S.%L')
            expect(filename).to match_regex(/#{timestamp}/)
          end
        end

        it 'uses a file name that includes the pid' do
          expect(diagnostics.collect(output_dir, updater)).to match_regex(/#{Process.pid}/)
        end
      end

      describe 'file contents' do
        it 'captures the data as json' do
          filename = diagnostics.collect(output_dir, updater)
          contents = IO.read(filename)
          expect {
            JSON.parse(contents)
          }.to_not raise_exception
        end

        def data
          JSON.parse(IO.read(diagnostics.collect(output_dir, updater)), symbolize_names: true)
        end

        it 'captures thread information' do
          expect(data[:threads]).to_not be_nil
          expect(data[:threads].empty?).to be false
        end

        it 'captures varz information' do
          expect(data[:varz]).to_not be_nil
          expect(data[:varz].empty?).to be false
        end
      end

      it 'updates varz with the latest data' do
        expect(updater).to receive(:update!)
        diagnostics.collect(output_dir, updater)
      end
    end
  end
end
