require 'spec_helper'

RSpec.describe 'DnsApi::Routes::DNS' do
  def app
    @app ||= DnsApi::Routes::DNS
  end

  describe 'v1 API' do
    prefix = '/v1/dns'

    describe "when GET #{prefix}/:account/macs/:mac" do
      let(:route) { "#{prefix}/bam-test/macs/00-00-00-00-00-00" }
      context 'non-existent account' do
        subject do
          header 'Auth-Token', 'test'
          get "#{prefix}/bork/ips/00-00-00-00-00-00"
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
          header 'Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'Auth-Token', 'test'
          get route
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_mac_address).with('00-00-00-00-00-00').and_return(entity)
          expect(entity).to receive(:type).and_return('MACAddress')
          expect(entity).to receive(:to_h).and_return(id: '12345', address: '00-00-00-00-00-00')
          expect(subject.status).to eq(200)
        end
      end
    end

    describe "when POST #{prefix}/:account/macs" do
      let(:route) { "#{prefix}/bam-test/macs" }
      let(:params) { { 'mac' => '00-00-00-00-00-00', 'macpool' => 12345 } }
      let(:badparams) { { 'macpool' => 12345 } }

      context 'non-existent account' do
        subject do
          header 'Auth-Token', 'test'
          get "#{prefix}/bork/macs"
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
          header 'Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'given params with valid token' do
        subject do
          header 'Auth-Token', 'test'
          post route, params.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)

          expect(client).to receive(:add_mac_address).with('00-00-00-00-00-00', '').and_return(
            id: 10000,
            type: 'MACAddress',
            properties: '',
            name: '00-00-00-00-00-00'
          )

          expect(client).to receive(:associate_mac_address_with_pool).with('00-00-00-00-00-00', 12345).and_return(
            id: 10000,
            type: 'MACAddress',
            properties: '',
            name: '00-00-00-00-00-00',
            macPool: 'Test'
          )

          expect(subject.status).to eq(200)
        end
      end

      context 'with empty body' do
        subject do
          header 'Auth-Token', 'test'
          post route
        end
        it 'returns status code 400' do
          expect(subject.status).to eq(400)
        end
      end

      context 'with bad json params' do
        subject do
          header 'Auth-Token', 'test'
          post route, badparams.to_json
        end
        it 'returns status code 422' do
          expect(subject.status).to eq(422)
        end
      end
    end
  end
end
