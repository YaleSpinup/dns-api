require 'spec_helper'

RSpec.describe 'DnsApi::Routes::DNS' do
  def app
    @app ||= DnsApi::Routes::DNS
  end

  describe 'v1 API' do
    prefix = '/v1/dns'
    valid_token = '$2a$10$mLHLxLBpK0Ile.nNvilpu.nkHyZPL0NDtdbDbTH/QEP7yypEvlfCK'

    describe "when GET #{prefix}/:account/ips/:ip" do
      let(:route) { "#{prefix}/bam-test/ips/192.168.1.234" }
      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          get "#{prefix}/bork/ips/192.168.1.234"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          get route
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          allow(client).to receive_message_chain(:get_entities, :first, :id).and_return('12345')
          expect(client).to receive(:get_ip4_address).with('12345', '192.168.1.234').and_return(entity)
          expect(entity).to receive(:type).and_return('IP4Address')
          expect(entity).to receive(:to_h).and_return(id: '12345', ip: '192.168.1.234')
          expect(subject.status).to eq(200)
        end
      end
    end

    describe "when POST #{prefix}/:account/ips" do
      let(:route) { "#{prefix}/bam-test/ips" }
      let(:cidr) { { 'hostname' => 'foo.example.com', 'cidr' => '192.168.1.0/24' } }
      let(:network) { { 'hostname' => 'foo.example.com', 'network_id' => '12345' } }
      let(:badparams) { { 'hostname' => 'foo.example.com' } }

      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          get "#{prefix}/bork/ips"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'given CIDR with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, cidr.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          allow(client).to receive_message_chain(:get_entities, :first, :id).and_return('54321')

          ip4 = double('ipv4 address')
          allow(ip4).to receive(:id).and_return('99999')

          expect(client).to receive(:get_ip4_address).with(
            '54321',
            '192.168.1.0'
          ).and_raise(DnsApi::ErrorHandling::NotFound, 'boom')

          expect(client).to receive(:get_ip4_address).with(
            '54321',
            '192.168.1.1'
          ).and_return(ip4)
          expect(ip4).to receive(:type).and_return('IP4Address')

          parent = double('ipv4 address parent')
          expect(client).to receive(:get_parent).with('99999').and_return(parent)
          allow(parent).to receive(:id).and_return('88888')

          expect(client).to receive(:assign_next_available_ip4_address).with(
            '54321', '88888', nil, 'foo.example.com,123456,,false', 'MAKE_STATIC', 'name=foo.example.com'
          ).and_return(
            id: 123456789,
            properties: 'address=192.168.1.123|state=STATIC|',
            name: 'foo.example.com'
          )

          expect(subject.status).to eq(200)
        end
      end

      context 'given network id with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, network.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          allow(client).to receive_message_chain(:get_entities, :first, :id).and_return('54321')

          expect(client).to receive(:assign_next_available_ip4_address).with(
            '54321', '12345', nil, 'foo.example.com,123456,,false', 'MAKE_STATIC', 'name=foo.example.com'
          ).and_return(
            id: 123456789,
            properties: 'address=192.168.1.123|state=STATIC|',
            name: 'foo.example.com'
          )

          expect(subject.status).to eq(200)
        end
      end

      context 'with empty body' do
        subject do
          header 'X-Auth-Token', valid_token
          post route
        end
        it 'returns status code 400' do
          expect(subject.status).to eq(400)
        end
      end

      context 'with bad json params' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, badparams.to_json
        end
        it 'returns status code 422' do
          # I dont understand why i have to do this here...
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(subject.status).to eq(422)
        end
      end
    end

    describe "when DELETE #{prefix}/:account/ips/:ip" do
      let(:route) { "#{prefix}/bam-test/ips/192.168.1.234" }
      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          delete "#{prefix}/bork/records/192.168.1.234"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          delete route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          delete route
        end

        context 'and existing IP' do
          it 'status code 200' do
            client = double('proteus client')
            entity = double('api entity')
            expect(Proteus::Client).to receive(:new).and_return(client)
            expect(client).to receive(:login!).and_return(client)
            allow(client).to receive_message_chain(:get_entities, :first, :id).and_return('12345')
            expect(client).to receive(:get_ip4_address).with('12345', '192.168.1.234').and_return(entity)
            expect(entity).to receive(:type).and_return('IP4Address')
            expect(entity).to receive(:id).and_return('12345')
            expect(client).to receive(:delete).with('12345').and_return(entity)
            expect(subject.status).to eq(200)
          end
        end

        context 'and nonexistent IP' do
          it 'status code 404' do
            client = double('proteus client')
            expect(Proteus::Client).to receive(:new).and_return(client)
            expect(client).to receive(:login!).and_return(client)
            allow(client).to receive_message_chain(:get_entities, :first, :id).and_return('12345')

            expect(client).to receive(:get_ip4_address).with(
              '12345', '192.168.1.234'
            ).and_raise(Proteus::ApiEntityError::EntityNotFound, 'boom')

            expect(subject.status).to eq(404)
          end
        end
      end
    end
  end
end
