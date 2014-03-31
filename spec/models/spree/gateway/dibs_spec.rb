require 'spec_helper'

describe Spree::Gateway::Dibs do

  # you must use your own dibs account for these tests.
  let(:login) { DIBS_CONFIG['merchantid'] }
  let(:password) { DIBS_CONFIG['hmackey'] }

  before do
    @gateway = described_class.create!(name: 'DIBS', environment: 'test', active: true)
    @gateway.set_preference(:login, login)
    @gateway.set_preference(:password, password)
    @gateway.save!

    country = create(:country, name: 'United States', iso_name: 'UNITED STATES', iso3: 'USA', iso: 'US', numcode: 840)
    state   = create(:state, name: 'Maryland', abbr: 'MD', country: country)
    address = create(:address,
      firstname: 'John',
      lastname: 'Doe',
      address1: '1234 My Street',
      address2: 'Apt 1',
      city: 'Washington DC',
      zipcode: '20123',
      phone: '(555)555-5555',
      state: @state,
      country: @country
    )

    @order = create(:order_with_totals, bill_address: address, ship_address: address, last_ip_address: '127.0.0.1')
    @order.update!

    # this card info is from http://tech.dibs.dk/10_step_guide/your_own_test/
    @credit_card = create(:credit_card,
      verification_value: '684',
      number: '4020051000000000',
      month: '6',
      year: '2024',
      first_name: 'John',
      last_name: 'Doe')

    @payment = create(:payment, source: @credit_card, order: @order, payment_method: @gateway, amount: 10.00)
    @payment.payment_method.environment = 'test'

    @options = {
      order_id: @order.number + '-' + DateTime.current.to_i.to_s,
      billing_address: address,
      description: 'Store Purchase',
      currency: 'USD'
    }
  end

  it '.provider_class' do
    expect(@gateway.provider_class).to eq ::ActiveMerchant::Billing::DibsGateway
  end

  it '.actions' do
    expect(@gateway.actions).to match_array ['authorize', 'capture', 'refund', 'credit', 'void']
  end

  context 'with bad parameters' do
    it 'throw an exception' do
      params = @credit_card.delete(:cardno)
      expect { @gateway.authorize(10, @credit_card, @options) }.to raise_error
    end
  end

  context '.authorize' do
    it 'return a success' do
      result = @gateway.authorize(10, @credit_card, @options)
      expect(result.success?).to be_true
    end
  end

  context '.capture' do
    it 'capture a previous authorization' do
      @payment.process!
      capture_result = @gateway.capture(10, @payment.response_code, nil)
      expect(capture_result.success?).to be_true
    end
  end
end
