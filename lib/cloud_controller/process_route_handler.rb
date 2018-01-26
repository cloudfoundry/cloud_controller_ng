require 'cf-copilot'

module VCAP::CloudController
  class ProcessRouteHandler
    def initialize(process, runners = nil)
      @process = process

      ca_cert = <<EOF
-----BEGIN CERTIFICATE-----
MIIE5DCCAsygAwIBAgIBATANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdmYWtl
X2NhMB4XDTE4MDEyNTIzMTUxMVoXDTE5MDcyNTIzMTUxMVowEjEQMA4GA1UEAwwH
ZmFrZV9jYTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOzJoHBADaNL
RAPPrRha1F4VSX/DeXDN/XI77Ju1xN8eIlhabT6RtQPHuGqG0HYd+ywAeOWEeBnX
ddeSjLub/RlLDR+daLVM3L5JdEXb8y4M79m7YymXd50RnKNvZfOktrFitfFiSOS2
2lXeHzf0+HvSizR7NybWOwVEulbju5s4dXEvjrFYThTZExYLWPkitP0KzBZngONM
HhNxU4Bgot7h6109X1Kq+66Kxaaibi906/H11yCaZFuOvo1XuqiTTlIhmC3VAc0p
wiR1BZy9npHCLacr1Ti9gGd3ambzonKetZoRSjbqFVAb32aDcGw3qyTqIP4x2zoE
Zq2flJLiu4fAaEowYrPkBUaGtbGfkyke4zF+IvmEGSDIWubOnV/SuWUVgrJBH5R4
0RMBLpBXP3g3HZ9VCR4TC3gyCF4g2dW8ljfPIEHYWBSnO+PRW2+JIDyzmr18I6JM
bVn50uCkC+yk6oDiSUaqlqJtG81W0hx2s/Ulk3dKmfDtXxjUbK9fHilesNaj8SS0
gTGAo4aFz3rbjJxlxvphc4/db0z5u9fpCdR23B1+qQk8TzyYesKECmyJ6C9QREr7
dfLYup2Na96DQhhajxubyjR9aeNcQlSX7YujcYG+VxpBKfuxjYSwUqggZAEhG0GS
UN+i1JM+O5Q8cHrBxF++dWLa8lPPtFs/AgMBAAGjRTBDMA4GA1UdDwEB/wQEAwIB
BjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBTbHnrZnr4WEc5R5c+6+plK
T9EjUTANBgkqhkiG9w0BAQsFAAOCAgEAhL1L1IAOrsMXNhKtyEa2pieqjsRRRQis
8/gR7BGoxZNr3KT9a10Rvr+nmBfBWjiH5fjXMe1fU9li4Bi+iAMuda7ykmUWsVak
KTcaMxImW0siag+S8asuUs0FnWM3xtAVpcUSaV3hGqzvcwOyw80XG9ME+ZI6UMK7
UzT4Tz/PAXngBQysDTkCZt5AmFwMBiLe1kR9Qauw6lcQxRwaNCyj1VnpanHMPiyT
o7xWnf8Ka6LPzhEqjPzdrMIKahyuux3zCLBSTPy3wAU1AqdnRPspNHCSUSDjjMMD
SL8V6Jkh0dBPQjdyG0cDMi2PCVlHQkP02avj+yAkjuJzhwAVl9Qq1BheJMdSD79A
qH4W+Rg5jseMmJms33jxx5T85NP2BkJWlpIZmkqku6iNFOd/kUtZqGhGtPdABjGv
x+1HLxX2nqqYcBOjGcgEgr8VwvfPM0FI07vwoDVQzq+t0UrZCPpdzodrtJHAToKN
C7KeEZSxu9omilwTH6N90v2gs8+oGaBogKKU4VThiRMmuG2DS259o+gNyvkheLGl
c32S3r6VLT6blqaF/Tc+4PQrKl5KOBFCARbPzHz0o9MfCGpFMw5NdMkFxAFN7e0A
rBCy/3TCbMmOccP8KS76o2ekou5yoxVRx8KuDzSDyJplwHdgnymupc4VOr0cIfv8
TsDR4Mi9/pk=
-----END CERTIFICATE-----
EOF
      key = <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAuAs4NGx5/DxNGLtKuerKQPk09KN/gMAAptqs/PQeJPcNx1aE
hh6ilzeiHF3AdTdOOXkKOvxLlCcgO51jXktvCI4gFCbd1zWyNQ7NdlRSkxAPKli6
7pOcUmxkOYBo/awb+0LE3S28FT+WlX8cmjx0ns9lDIkoaOHb3HRogAHE6GFGDtZ9
4y66lbDEVXMH2svKGUryRMEypCWA/Y7K/KAZtyqIrMh76C9umP+EBLcGWJ3NxxWE
FQ1SyHcZzrEB5JisVpgwaBBFlIqSrGD+E2h2hFfMKEu+TraUfPICLObuHnzcM6zY
9kbPfHO8fvrMkkO87+Cqjf/f4yO5J+v+LIfnMwIDAQABAoIBAHZSkEHz88Ecq5xY
3UQGFR4MmeUmMFUAG+sp78l40OCHDQ65Kt5nV7TMiaafB5rUgbAlh1RA2/5V4T0y
hK4c5Tek2C7chgdUeEvwRlvq/mOaEYXyIcw8jmXXVeA6FEXyntK9LH/eZWtrxE48
uJDYiUmIoLicfaRggM+M75pMiOG0f2g7kudTUeeRcD10I76We48ptgqyEO0kQb6K
GLlJJrcY97Pq27k4YqM0NTWM6n+BZ3vtqRzjuDHXHm9R9iY/wkm57U3K12I3UxIw
DESnVn6s7JNQ964vbwIq9MKG0Xee9VS/UAW56tZzbwt4dK7suiD3r6I2ybOsRoZZ
iKSQx2ECgYEA8hTi56V4f52m4AsqMa9UZQanUlhT+pEYctETwNNBByecbeFvf60M
rSVX21y2FmnO3XO3ZsORogRVrLppxy30ysDmX8MRlSNYLpTM4ltEyaunxAivgumb
4UI6j7Zh+u0+nvYtNR3+18tS8dUwzkSixw6IARJYg51AipQ213bH+vsCgYEAwqAY
iIdJ//FSnvJ2OmSEa6lDlRsmOArzZdG1Vf30PzFFnWhbPEtYcVmoQ443i/VMRxGP
JwlMBmCpLuuqMjGdsVVctdoJRCbihauUXFZ6ff1Hqk+TanzqNSIuuP6e+p1IBxgR
QuqhbMuwqKUmbjMtlfTgEJpe5nvUONRIDBKkDykCgYBJ+8Ig43xBHDBM1nyttJTJ
T1BBpUb9E+zx4h30V1vPUPbIyhXmYj+2huwj2WC41ttm6J+LY4eViVeZs1ryiYP/
lxaQ+6/a8XNYwRcgsp4COFjMW48wJi8Cl9gH5chqBKmXsUq9qg4haz1NNUd2MpnA
1hsQoMe2aY+5CnT8Qov5kwKBgDXHQSAwqez0BM1w1+RotAJ/wfHoj5X6yKjA2qeJ
Rb1UYxUMqfEuLKEdkhYgrQ6aWFpm6rRxqDU27mjNq7i05wsCOFzzg432ZK9k6tjc
+Hnpy6yu0mAhZiIKcPijOtCrNyTmrJZd+P70BbuD7uuSbq05/dP4o/JyEwEk/0d+
uyCJAoGAL8fGUtpJPEOrWvml/ri8Kw9Ld+EI212ggwQK9mz/E+Y0FXKTmk70wswf
Ldm8JHpCkdRhiJo1cSQvdEZZcOGl3gbAmatN/xCOh5g4k8ne+tEY4wYfxI74dZ1t
WvnoCbUAvB/gxI+nTjgqJGggmJyiFEEjDRERWswDcmCM0S1dMIs=
-----END RSA PRIVATE KEY-----
EOF
      cert = <<EOF
-----BEGIN CERTIFICATE-----
MIIEHDCCAgSgAwIBAgIQGUaI6n/WIwl6lBIRYmatBTANBgkqhkiG9w0BAQsFADAS
MRAwDgYDVQQDDAdmYWtlX2NhMB4XDTE4MDEyNTIzMTUxNVoXDTE5MDcyNTIzMTUx
MFowDzENMAsGA1UEAxMEZmFrZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBALgLODRsefw8TRi7SrnqykD5NPSjf4DAAKbarPz0HiT3DcdWhIYeopc3ohxd
wHU3Tjl5Cjr8S5QnIDudY15LbwiOIBQm3dc1sjUOzXZUUpMQDypYuu6TnFJsZDmA
aP2sG/tCxN0tvBU/lpV/HJo8dJ7PZQyJKGjh29x0aIABxOhhRg7WfeMuupWwxFVz
B9rLyhlK8kTBMqQlgP2OyvygGbcqiKzIe+gvbpj/hAS3BlidzccVhBUNUsh3Gc6x
AeSYrFaYMGgQRZSKkqxg/hNodoRXzChLvk62lHzyAizm7h583DOs2PZGz3xzvH76
zJJDvO/gqo3/3+MjuSfr/iyH5zMCAwEAAaNxMG8wDgYDVR0PAQH/BAQDAgO4MB0G
A1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQU3TG+SdmTfyRe
m+9HTzGNGFSZizQwHwYDVR0jBBgwFoAU2x562Z6+FhHOUeXPuvqZSk/RI1EwDQYJ
KoZIhvcNAQELBQADggIBAAm5/3RiXRc4qtFnJ/qKbTx3190fhoG/9LF1JgC7kW6L
gSEHjc3i7FJ+WxRPzcYdbrkspHaWXBQhbV9Xr1boiXVfr25JfaGq/NEIY307my5W
4hrkjb4E2hG9/PgQ/RK1f0o4MInWlSvzemHWLMth/fWC1ObcTPmTDPZwCwMsDwRd
zAyaMls7N2ET+qs/9XwtipLdKD79ymLrO36pbvDoRjwRTMeVwSgh9t9NC9kZz5zq
jAUSetCYdaz19cJ9N+bC45WmcNeiQoBQIpiyxkm8f2/FxL/wePPVvbFQEejbTq2I
bp28JGMJmWvUAtsq07+OiYIF+MH1V/bJNHRoDD84//u8z2m9/Iu+QH4Wp+p8U0Pc
466xn0o0GEw2oZS6HuPTW7ivJ6vCa2NEX/ThAyO34KaW7WLYxZr260sXIc42ntPU
uaZmqUmT0QZJge9dHAVR3nQYGpq8fYO7nWmQrekJYVlruIHaR+Uc7lUain0nB6tQ
xt3s+0+hx6vNMuGMGyKTu1CC1VhUMK86DdAtmkl4QGl4n8N52Hv6RwyziDIMRjNF
ApB6ftzl+Krnv1NNaBbW5Vx8NJL04f7BvcQhOa91QJcauFOuCCmvA5Jdvp2R5IbZ
Wnp+X6eevqgnEJSJDRvn9N0QXK8DqhP+SZbzyRrjaNhtOthE9RpSVylVmYXNy9ri
-----END CERTIFICATE-----
EOF
      @copilot_client = Cloudfoundry::Copilot::Client.new(
          host: 'localhost',
          port: 9000,
          client_ca: ca_cert,
          client_key: key,
          client_chain: cert
      )
      puts '********************************************************************************'
      puts @copilot_client.inspect
      puts '********************************************************************************'

      @runners = runners || CloudController::DependencyLocator.instance.runners
    end

    def update_route_information
      return unless @process

      with_transaction do
        @process.lock!

        if @process.diego?
          @process.update(updated_at: Sequel::CURRENT_TIMESTAMP)
        elsif @process.dea?
          @process.set_new_version
          @process.save_changes
        end

        @process.db.after_commit do
          notify_copilot_of_route_update
          notify_backend_of_route_update
        end
      end
    end

    def notify_copilot_of_route_update
      route_guid = 'some-guid'
      host = 'some-host'
      path = '/'
      # call copilot sdk
      @copilot_client.upsert_route(
          guid: route_guid,
          host: host,
          path: path
      )
      route_mapping_guid = 'some-route-mapping-guid'
      app_guid = 'some-app-guid'
      @copilot_client.map_route(
          guid: route_mapping_guid,
          app_guid: app_guid,
          route_guid: route_guid
      )
    end

    def notify_backend_of_route_update
      @runners.runner_for_process(@process).update_routes if @process && @process.staged? && @process.started?
    rescue Diego::Runner::CannotCommunicateWithDiegoError => e
      logger.error("failed communicating with diego backend: #{e.message}")
    end

    private

    def with_transaction
      if @process.db.in_transaction?
        yield
      else
        @process.db.transaction do
          yield
        end
      end
    end

    def logger
      @logger ||= Steno.logger('cc.process_route_handler')
    end
  end
end
