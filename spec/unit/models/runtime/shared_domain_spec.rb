require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SharedDomain, type: :model do
    subject { SharedDomain.make name: 'test.example.com', router_group_guid: router_group_guid, router_group_type: 'tcp' }

    let(:router_group_guid) { 'my-router-group-guid' }

    it { is_expected.to have_timestamp_columns }

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :internal, :router_group_guid, :router_group_type }
      it { is_expected.to import_attributes :name, :internal, :router_group_guid }
    end

    describe '#as_summary_json' do
      it 'returns a hash containing the shared domain attributes' do
        expect(subject.as_summary_json).to eq(
          guid: subject.guid,
          name: 'test.example.com',
          internal: false,
          router_group_guid: 'my-router-group-guid',
          router_group_type: 'tcp'
        )
      end
    end

    describe '#validate' do
      include_examples 'domain validation'

      context 'when the name is foo.com and bar.foo.com is a shared domain' do
        before do
          SharedDomain.make name: 'bar.foo.com'
          subject.name = 'foo.com'
        end

        it { is_expected.to be_valid }
      end

      it 'allows shared foo.com when private bar.foo.com exists' do
        PrivateDomain.make name: 'bar.foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to_not raise_error
      end

      it 'allows shared foo.com when shared bar.foo.com exists' do
        SharedDomain.make name: 'bar.foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to_not raise_error
      end

      it 'allows shared bar.foo.com a when shared baz.bar.foo.com and foo.com exist' do
        SharedDomain.make name: 'baz.bar.foo.com'
        SharedDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to_not raise_error
      end

      it 'allows shared bar.foo.com a when private baz.bar.foo.com and shared foo.com exist' do
        PrivateDomain.make name: 'baz.bar.foo.com'
        SharedDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to_not raise_error
      end

      it 'denies shared bar.foo.com when private foo.com exists' do
        PrivateDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to raise_error(Sequel::ValidationFailed,
          %{The domain name "bar.foo.com" cannot be created because "foo.com" is already reserved by another domain}
        )
      end

      it 'denies shared foo.com when private foo.com exists' do
        PrivateDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end

      context 'when the domain is internal' do
        subject { SharedDomain.make(name: 'test.example.com', internal: true) }

        it { is_expected.to be_valid }

        context 'and when there is a router_group_guid set' do
          it 'is not valid' do
            subject.router_group_guid = router_group_guid
            expect { subject.save }.to raise_error(Sequel::ValidationFailed, /cannot be specified for internal domains/)
          end
        end
      end
    end

    describe '#destroy' do
      let(:routing_api_client) { double('routing_api_client') }
      let(:router_group) { double('router_group', type: 'tcp', guid: 'router-group-guid') }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:routing_api_client).
          and_return(routing_api_client)
        allow(routing_api_client).to receive(:router_group).with(router_group_guid).and_return(router_group)
        allow_any_instance_of(RouteValidator).to receive(:validate)
        TestConfig.override(kubernetes: {})
      end

      it 'destroys the routes' do
        route = Route.make(domain: subject)

        expect do
          subject.destroy
        end.to change { Route.where(id: route.id).count }.by(-1)
      end
    end

    describe '#tcp?' do
      let(:router_group_type) { 'http' }
      let(:ra_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group: rg) }
      let(:rg) { instance_double(VCAP::CloudController::RoutingApi::RouterGroup, type: router_group_type) }
      let(:shared_domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: '123') }

      before do
        allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(ra_client)
        TestConfig.override(kubernetes: nil)
      end

      context 'when kubernetes is enabled' do
        before do
          TestConfig.override(kubernetes: { host_url: 'kube.com' })
        end

        it 'returns false' do
          expect(shared_domain.tcp?).to be_falsy
          expect_any_instance_of(CloudController::DependencyLocator).not_to receive(:routing_api_client)
        end
      end

      context 'when shared domain is a tcp domain' do
        let(:router_group_type) { 'tcp' }

        it 'returns true' do
          expect(shared_domain.tcp?).to be_truthy
        end
      end

      context 'when shared domain is not a tcp domain' do
        it 'returns false' do
          expect(shared_domain.tcp?).to eq(false)
        end
      end

      context 'when there is no router group guid' do
        let(:shared_domain) { SharedDomain.make(name: 'tcp.com') }
        it 'returns false' do
          expect(shared_domain.tcp?).to eq(false)
        end
      end

      context 'when the router group doesnt match' do
        let(:router_group_type) { 'http' }
        let(:ra_client) { instance_double(VCAP::CloudController::RoutingApi::Client, router_group: nil) }
        let(:rg) { instance_double(VCAP::CloudController::RoutingApi::RouterGroup, type: router_group_type) }
        let(:shared_domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: '123') }

        it 'returns false' do
          expect(shared_domain.tcp?).to eq(false)
        end

        it 'when tcp? is called twice it only calls the routing api once' do
          expect(ra_client).to receive(:router_group).once
          shared_domain.tcp?
          shared_domain.tcp?
        end
      end

      it 'when tcp? is called twice it only calls the routing api once' do
        expect(ra_client).to receive(:router_group).once
        shared_domain.tcp?
        shared_domain.tcp?
      end
    end

    describe 'addable_to_organization!' do
      it 'does not raise error' do
        expect { subject.addable_to_organization!(Organization.new) }.to_not raise_error
      end
    end

    describe '.find_or_create' do
      context 'when an invalid domain name is requested' do
        it 're-raises original err types with an updated message' do
          expected_error = StandardError.new('original message')
          expected_error.set_backtrace(['original', 'backtrace'])
          allow(SharedDomain).to receive(:new).and_raise(expected_error)

          expect { SharedDomain.find_or_create(name: 'invalid_domain') }.to raise_error do |e|
            expect(e).to be_a(StandardError)
            expect(e.message).to eq('Error for shared domain name invalid_domain: original message')
            expect(e.backtrace).to eq(['original', 'backtrace'])
          end
        end
      end

      context 'when a router group guid is requested' do
        context 'and it does not exist' do
          before do
            SharedDomain.dataset.destroy
          end

          it 'creates the domains' do
            SharedDomain.find_or_create(name: 'some-domain.com', router_group_guid: 'some-guid')
            expect(SharedDomain.count).to eq(1)
            expect(SharedDomain.last[:router_group_guid]).to eq('some-guid')
            expect(SharedDomain.last[:name]).to eq('some-domain.com')
          end
        end

        context 'and it already exists' do
          before do
            SharedDomain.make(router_group_guid: '123', name: 'wee.example.com')
          end

          it 'returns the found domain' do
            domain = SharedDomain.find_or_create(name: 'wee.example.com')
            expect(domain[:name]).to eq('wee.example.com')
            expect(domain[:router_group_guid]).to eq('123')
          end
        end

        context 'and the domain is internal' do
          it 'raises an error' do
            attrs = { name: 'some-domain.com', router_group_guid: 'some-guid', internal: true }
            expect { SharedDomain.find_or_create(attrs) }.to raise_error do |e|
              expect(e).to be_a(StandardError)
              expect(e.message).to eq('Error for shared domain name some-domain.com: router_group_guid cannot be specified for internal domains')
            end
          end
        end
      end

      context 'when the domain already exists' do
        let(:is_internal) { false }
        let(:domain_name) { 'existing.example.com' }
        let!(:existing_domain) { SharedDomain.make(name: domain_name, internal: is_internal) }
        let(:attrs) { { name: domain_name } }
        let(:fake_logger) { instance_double(Steno::Logger, info: nil, warn: nil) }

        before do
          allow(Steno).to receive(:logger).and_return(fake_logger)
          expect_any_instance_of(SharedDomain).not_to receive(:save)
        end

        context 'when the domain is internal' do
          let(:is_internal) { true }

          it 'ignores trying to make the domain external' do
            before_updated_at = existing_domain.updated_at

            expect {
              SharedDomain.find_or_create(attrs.merge(internal: false))
            }.not_to change { existing_domain.reload }
            expect(fake_logger).to have_received(:warn).
              with("Domain '#{domain_name}' already exists. Skipping updates of internal status")
            expect(existing_domain.updated_at).to eq(before_updated_at)

            existing_domain.reload
            expect(existing_domain).to be_internal
          end
        end

        context 'when the domain is external' do
          let(:is_internal) { false }

          it 'ignores trying to make the domain internal' do
            before_updated_at = existing_domain.updated_at

            expect {
              SharedDomain.find_or_create(attrs.merge(internal: true))
            }.not_to change { existing_domain.reload }
            expect(fake_logger).to have_received(:warn).
              with("Domain '#{domain_name}' already exists. Skipping updates of internal status")
            expect(existing_domain.updated_at).to eq(before_updated_at)
            expect(fake_logger).not_to have_received(:info).with("creating shared serving domain: #{domain_name}")

            existing_domain.reload
            expect(existing_domain).not_to be_internal
          end
        end

        it 'ignores trying to change the router group guid' do
          before_updated_at = existing_domain.updated_at

          expect {
            SharedDomain.find_or_create(attrs.merge(router_group_guid: 'new rgg'))
          }.not_to change { existing_domain.reload }
          expect(fake_logger).to have_received(:warn).
            with("Domain '#{domain_name}' already exists. Skipping updates of router_group_guid")
          expect(existing_domain.updated_at).to eq(before_updated_at)
          expect(fake_logger).not_to have_received(:info).with("creating shared serving domain: #{domain_name}")

          existing_domain.reload
          expect(existing_domain.router_group_guid).to be_nil
        end

        it 'ignores trying to update the existing domain' do
          before_updated_at = existing_domain.updated_at

          expect {
            SharedDomain.find_or_create(attrs)
          }.not_to change { existing_domain.reload }
          expect(existing_domain.updated_at).to eq(before_updated_at)
          expect(fake_logger).to have_received(:info).with("reusing default serving domain: #{domain_name}")
          expect(fake_logger).not_to have_received(:info).with("creating shared serving domain: #{domain_name}")
        end
      end
    end
  end
end
