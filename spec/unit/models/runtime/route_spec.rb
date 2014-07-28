require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Route, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :domain }
      it { is_expected.to have_associated :space }
      it { is_expected.to have_associated :apps, associated_instance: ->(route) { App.make(space: route.space) } }
    end

    describe "Validations" do
      let(:route) { Route.make }

      it { is_expected.to validate_presence :domain }
      it { is_expected.to validate_presence :space }
      it { is_expected.to validate_presence :host }
      it { is_expected.to validate_uniqueness [:host, :domain_id] }

      describe "host" do
        let(:space) { Space.make }
        let(:domain) { PrivateDomain.make(owning_organization: space.organization) }

        it "should not allow . in the host name" do
          route.host = "a.b"
          expect(route).not_to be_valid
        end

        it "should not allow / in the host name" do
          route.host = "a/b"
          expect(route).not_to be_valid
        end

        it "should not allow a nil host" do
          expect {
            Route.make(space: space, domain: domain, host: nil)
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should allow an empty host" do
          Route.make(:space => space,
            :domain         => domain,
            :host           => "")
        end

        it "should not allow a blank host" do
          expect {
            Route.make(:space => space,
              :domain         => domain,
              :host           => " ")
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe "total allowed routes" do
        let(:space) { Space.make }
        let(:org_quota) { space.organization.quota_definition }
        let(:space_quota) { nil }

        before do
          space.space_quota_definition = space_quota
        end

        subject(:route) { Route.new(space: space) }

        context "for organizatin quotas" do
          context "on create" do
            context "when not exceeding total allowed routes" do
              before do
                org_quota.total_routes = 10
                org_quota.save
              end

              it "does not have an error on organization" do
                subject.valid?
                expect(subject.errors.on(:organization)).to be_nil
              end
            end

            context "when exceeding total allowed routes" do
              before do
                org_quota.total_routes = 0
                org_quota.save
              end

              it "has the error on organization" do
                subject.valid?
                expect(subject.errors.on(:organization)).to include :total_routes_exceeded
              end
            end
          end

          context "on update" do
            it "should not validate the total routes limit if already existing" do
              expect {
                org_quota.total_routes = 0
                org_quota.save
              }.not_to change {
                subject.valid?
              }
            end
          end
        end

        context "for space quotas" do
          let(:space_quota) { QuotaDefinition.make }

          context "on create" do
            context "when not exceeding total allowed routes" do
              before do
                space_quota.total_routes = 10
                space_quota.save
              end

              it "does not have an error on the space" do
                subject.valid?
                expect(subject.errors.on(:space)).to be_nil
              end
            end

            context "when exceeding total allowed routes" do
              before do
                space_quota.total_routes = 0
                space_quota.save
              end

              it "has the error on the space" do
                subject.valid?
                expect(subject.errors.on(:space)).to include :total_routes_exceeded
              end
            end
          end

          context "on update" do
            it "should not validate the total routes limit if already existing" do
              expect {
                space_quota.total_routes = 0
                space_quota.save
              }.not_to change {
                subject.valid?
              }
            end
          end
        end

        describe "quota evaluation order" do
          let(:space_quota) { QuotaDefinition.make }

          before do
            org_quota.total_routes   = 0
            space_quota.total_routes = 10

            org_quota.save
            space_quota.save
          end

          it "fails when the space quota is valid and the organization quota is exceeded" do
            subject.valid?
            expect(subject.errors.on(:space)).to be_nil
            expect(subject.errors.on(:organization)).to include :total_routes_exceeded
          end
        end
      end
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :host, :domain_guid, :space_guid }
      it { is_expected.to import_attributes :host, :domain_guid, :space_guid, :app_guids }
    end

    describe "instance methods" do
      let(:space) { Space.make }

      let(:domain) do
        PrivateDomain.make(
          :owning_organization => space.organization
        )
      end

      describe "#fqdn" do
        context "for a non-nil host" do
          it "should return the fqdn for the route" do
            r = Route.make(
              :host   => "www",
              :domain => domain,
              :space  => space,
            )
            expect(r.fqdn).to eq("www.#{domain.name}")
          end
        end

        context "for a nil host" do
          it "should return the fqdn for the route" do
            r = Route.make(
              :host   => "",
              :domain => domain,
              :space  => space,
            )
            expect(r.fqdn).to eq(domain.name)
          end
        end
      end

      describe "#as_summary_json" do
        it "returns a hash containing the route id, host, and domain details" do
          r = Route.make(
            :host   => "www",
            :domain => domain,
            :space  => space,
          )
          expect(r.as_summary_json).to eq({
            :guid   => r.guid,
            :host   => r.host,
            :domain => {
              :guid => r.domain.guid,
              :name => r.domain.name
            }
          })
        end
      end

      describe "#in_suspended_org?" do
        let(:space) { Space.make }
        subject(:route) { Route.new(space: space) }

        context "when in a suspended organization" do
          before { allow(space).to receive(:in_suspended_org?).and_return(true) }
          it "is true" do
            expect(route).to be_in_suspended_org
          end
        end

        context "when in an unsuspended organization" do
          before { allow(space).to receive(:in_suspended_org?).and_return(false) }
          it "is false" do
            expect(route).not_to be_in_suspended_org
          end
        end
      end
    end

    describe "relations" do
      let(:org) { Organization.make }
      let(:space_a) { Space.make(:organization => org) }
      let(:domain_a) { PrivateDomain.make(:owning_organization => org) }

      let(:space_b) { Space.make(:organization => org) }
      let(:domain_b) { PrivateDomain.make(:owning_organization => org) }

      it "should not associate with apps from a different space" do
        route = Route.make(space: space_b, domain: domain_a)
        app   = AppFactory.make(space: space_a)
        expect {
          route.add_app(app)
        }.to raise_error Route::InvalidAppRelation
      end

      it "should not allow creation of a empty host on a shared domain" do
        shared_domain = SharedDomain.make

        expect {
          Route.make(
            host:   "",
            space:  space_a,
            domain: shared_domain
          )
        }.to raise_error Sequel::ValidationFailed
      end
    end

    describe "#remove" do
      it "marks the apps routes as changed" do
        app   = AppFactory.make
        route = Route.make(app_guids: [app.guid], space: app.space)
        app   = route.apps.first

        expect(app).to receive(:mark_routes_changed).and_call_original
        route.destroy
      end
    end

    describe "apps association" do
      let(:route) { Route.make }
      let!(:app) do
        AppFactory.make({ :space => route.space })
      end

      describe "when adding an app" do
        it "marks the apps routes as changed" do
          expect(app).to receive(:mark_routes_changed).and_call_original
          route.add_app(app)
        end
      end

      describe "when removing an app" do
        it "marks the apps routes as changed" do
          route.add_app(app)
          expect(app).to receive(:mark_routes_changed).and_call_original
          route.remove_app(app)
        end
      end
    end
  end
end
