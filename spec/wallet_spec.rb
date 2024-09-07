# frozen_string_literal: true

# spec/wallet_spec.rb
require "spec_helper"

RSpec.describe Webcash::Wallet do
  let(:default_wallet) { Webcash::Wallet.new }

  it 'initializes with default values' do
    expect(default_wallet.version).to eq("1.0")
    expect(default_wallet.legalese).to eq({ "terms" => nil })
    expect(default_wallet.webcash).to eq([])
    expect(default_wallet.unconfirmed).to eq([])
    expect(default_wallet.log).to eq([])
    expect(default_wallet.walletdepths).to eq({
      "RECEIVE" => 0,
      "PAY" => 0,
      "CHANGE" => 0,
      "MINING" => 0
    })
  end

  it 'generates a random master_secret if not provided' do
    wallet_without_secret = described_class.new(master_secret: "")
    expect(wallet_without_secret.master_secret).to be_a(String)
    expect(wallet_without_secret.master_secret.length).to eq(32)
  end

  it 'uses provided master_secret if given' do
    provided_secret = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    wallet_with_secret = described_class.new(master_secret: provided_secret)
    expect(wallet_with_secret.master_secret).to eq(provided_secret)
  end

  it 'returns false if legal agreements have not been accepted' do
    wallet = described_class.new(legalese: { "terms" => false })
    expect(wallet.check_legal_agreements).to be false
  end

  it 'returns true if legal agreements have been accepted' do
    wallet = Webcash::Wallet.new(legalese: { "terms" => true })
    expect(wallet.check_legal_agreements).to be true
  end

  it 'returns false if legal agreements are not present' do
    wallet = Webcash::Wallet.new(legalese: {})
    expect(wallet.check_legal_agreements).to be false
  end

  it 'sets legal agreements to true' do
    wallet = Webcash::Wallet.new(legalese: { "terms" => false })
    wallet.set_legal_agreements_to_true
    expect(wallet.legalese["terms"]).to be true
  end

  it 'sets legal agreements to true when not initially present' do
    wallet = Webcash::Wallet.new(legalese: {})
    wallet.set_legal_agreements_to_true
    expect(wallet.legalese["terms"]).to be true
  end

  it 'returns all contents of the wallet' do
    wallet = Webcash::Wallet.new(
      version: "1.1",
      legalese: { "terms" => true },
      webcash: [ 1, 2, 3 ],
      unconfirmed: [ 4, 5 ],
      log: [ 6, 7, 8 ],
      master_secret: "abcdef1234567890",
      walletdepths: { "RECEIVE" => 1, "PAY" => 2, "CHANGE" => 3, "MINING" => 4 }
    )

    expected_contents = {
      master_secret: "abcdef1234567890",
      walletdepths: { "RECEIVE" => 1, "PAY" => 2, "CHANGE" => 3, "MINING" => 4 },
      webcash: [ 1, 2, 3 ],
      unconfirmed: [ 4, 5 ],
      log: [ 6, 7, 8 ],
      version: "1.1",
      legalese: { "terms" => true }
    }

    expect(wallet.get_contents).to eq(expected_contents)
  end

  it 'returns contents with default values when no parameters are provided' do
    wallet = Webcash::Wallet.new

    expected_contents = {
      master_secret: wallet.master_secret,
      walletdepths: Webcash::Wallet::DEFAULT_WALLETDEPTHS,
      webcash: [],
      unconfirmed: [],
      log: [],
      version: "1.0",
      legalese: Webcash::Wallet::DEFAULT_LEGALESE
    }

    expect(wallet.get_contents).to eq(expected_contents)
  end

  it 'calculates the correct balance' do
    wallet = Webcash::Wallet.new(
      webcash: [ "10:secret:1", "20:secret:2", "30:secret:3" ]
    )
    expect(wallet.get_balance).to eq(BigDecimal('60'))
  end

  it 'returns zero balance when webcash is empty' do
    wallet = Webcash::Wallet.new(webcash: [])
    expect(wallet.get_balance).to eq(BigDecimal('0'))
  end

  describe '.generate_next_secret' do
    let(:wallet) do
      Webcash::Wallet.new(
        master_secret: "6fc3d1b067646ea749e4001e05c757c491b351424ae998339d6341d7a18e12d4"
      )
    end

    it 'generates the next secret correctly for chain code "RECEIVE" and depth 0' do
      next_secret = wallet.generate_next_secret("RECEIVE", 0)
      expect(next_secret).to eq("29a24ce26ec924e20a68773d6909b91855b4a39a4224bde1e33eb52e29fc7a70")
    end

    it 'generates the next secret correctly for chain code "RECEIVE" and depth 1' do
      next_secret = wallet.generate_next_secret("RECEIVE", 1)
      expect(next_secret).to eq("42755e0fe6fd0bdf8ac998044628435ac46f7e630cf37d49cfe0080fae29de53")
    end

    it 'generates the next secret correctly for chain code "PAY" and depth 0' do
      next_secret = wallet.generate_next_secret("PAY", 0)
      expect(next_secret).to eq("b16095ea71f638b3a5651bffa5255a608a3cd535050f4828c1585b684ee529c7")
    end

    it 'generates the next secret correctly for chain code "PAY" and depth 1' do
      next_secret = wallet.generate_next_secret("PAY", 1)
      expect(next_secret).to eq("d2ea5643e0d92397744beb56e0b0995f57f55017b71df82f6956fc047a0fdc2f")
    end

    it 'generates the next secret correctly for chain code "RECEIVE" and depth 100' do
      next_secret = wallet.generate_next_secret("RECEIVE", 100)
      expect(next_secret).to eq("b8cd5030dd4a48be10449aa6bb2e666db50bfe0afd63e9ac79747174ca49719b")
    end

    it 'generates the next secret correctly for chain code "RECEIVE" and depth 1234' do
      next_secret = wallet.generate_next_secret("RECEIVE", 1234)
      expect(next_secret).to eq("cc6d5193b96297bc802827d6a4a90a063d6acfa78c772bcb5154c986dd2f6872")
    end

    it 'generates the next secret correctly for chain code "RECEIVE" and depth 100000000' do
      next_secret = wallet.generate_next_secret("RECEIVE", 100000000)
      expect(next_secret).to eq("8c7fa87d19121f17c523159ce03fc7ec5bbd4ca4bbb63caefa49d8e9db40b845")
    end
  end


  xdescribe '.insert / .pay (live)' do
    let(:wallet) do
      Webcash::Wallet.new(
        master_secret: "b34453ec49bc160f98cbe93001919a7aa633f5d855a41545fcff9620db13fdb6"
      ).tap { |w| w.set_legal_agreements_to_true }
    end

    let (:first_webcash) { "e0.0000001:secret:3d68409c26e9681222c22dd30728623f17c19cf5c5a686cbb35f499e76b76ab5" }
    let (:second_webcash) { "e0.0000001:secret:3aa2243d5c7f209e958bf096549122fbe9335fbbd4ce29e8f9d186aece0b77a0" }

    it 'inserts new webcash and updates the balance' do
      wallet.insert(first_webcash)
      expect(wallet.get_balance).to eq(BigDecimal("0.0000001"))
      wallet.walletdepths["RECEIVE"] = 1

      wallet.insert(second_webcash)
      expect(wallet.get_balance).to eq(BigDecimal("0.0000002"))
    end

    it 'throws an error when trying to insert an existing webcash' do
      expect {
        wallet.insert(first_webcash)
      }.to raise_error(RuntimeError)
    end

    it 'throws an error when trying to pay more than available balance' do
      expect {
        wallet.pay(BigDecimal('200'))
      }.to raise_error(RuntimeError, /Wallet does not have enough funds to make the transfer./)
    end

    it 'pays the correct amount and updates the balance (live)' do
      wallet.webcash << "e0.0000001:secret:74ac8b760fa30e7b5bdd41d740f77b0c7053161caf6868baad5c2ef44e39c5df"
      wallet.webcash << "e0.0000001:secret:c8bc8228ef117785b514b075c384c0153037956ebd13a4f60fe1493fef4b734f"
      wallet.pay(BigDecimal('0.0000001'))
      expect(wallet.get_balance).to eq(BigDecimal("0.0000001"))
    end
  end

  xdescribe '.check (live)' do
    let(:wallet) do
      Webcash::Wallet.new(
        master_secret: "b34453ec49bc160f98cbe93001919a7aa633f5d855a41545fcff9620db13fdb6"
      ).tap { |w| w.set_legal_agreements_to_true }
    end

    it 'removes duplicate webcash and updates the balance' do
      wallet.webcash << "e0.0000001:secret:74ac8b760fa30e7b5bdd41d740f77b0c7053161caf6868baad5c2ef44e39c5df"
      wallet.webcash << "e0.0000001:secret:c8bc8228ef117785b514b075c384c0153037956ebd13a4f60fe1493fef4b734f"
      wallet.webcash << "e0.0000001:secret:c8bc8228ef117785b514b075c384c0153037956ebd13a4f60fe1493fef4b734f"
      expect(wallet.get_balance).to eq(BigDecimal("0.0000003"))

      wallet.check
      expect(wallet.get_balance).to eq(BigDecimal("0.0000001"))

      wallet.webcash.push("e420:secret:foobar")
      expect(wallet.get_balance).to eq(BigDecimal("420.0000001"))

      wallet.check
      expect(wallet.get_balance).to eq(BigDecimal("0.0000001"))
    end
  end

  describe '.process_healthcheck_results' do
    let(:wallet) do
      Webcash::Wallet.new(
        master_secret: "b34453ec49bc160f98cbe93001919a7aa633f5d855a41545fcff9620db13fdb6"
      ).tap { |w| w.set_legal_agreements_to_true }
    end

    it 'updates the balance based on health check results' do
      wallet.webcash << "e15:secret:74ac8b760fa30e7b5bdd41d740f77b0c7053161caf6868baad5c2ef44e39c5df"
      wallet.webcash << "e0.0000001:secret:c8bc8228ef117785b514b075c384c0153037956ebd13a4f60fe1493fef4b734f"
      expect(wallet.get_balance).to eq(BigDecimal("15.0000001"))

      webcashes_map = {
        "3b9a08058877743b7445cab273dad8c698253a9e0fdb99462b236f95b6397be0" => "e15:secret:74ac8b760fa30e7b5bdd41d740f77b0c7053161caf6868baad5c2ef44e39c5df",
        "9079ece46ffecc3fdad26acfe7d36c0c30d38ee20b539ac795ec2f0211123cd0" => "e0.0000001:secret:c8bc8228ef117785b514b075c384c0153037956ebd13a4f60fe1493fef4b734f"
      }

      results = {
        "e0.0000001:public:3b9a08058877743b7445cab273dad8c698253a9e0fdb99462b236f95b6397be0" => { "spent"=>false, "amount"=>"15" },
        "e0.0000001:public:9079ece46ffecc3fdad26acfe7d36c0c30d38ee20b539ac795ec2f0211123cd0"=>{ "spent"=>false, "amount"=>"1E-7" }
      }

      wallet.process_healthcheck_results(results, webcashes_map)
      expect(wallet.get_balance).to eq(BigDecimal("15.0000001"))
    end
  end

  describe '.recover' do
    let(:wallet) do
      Webcash::Wallet.new(
        master_secret: "b34453ec49bc160f98cbe93001919a7aa633f5d855a41545fcff9620db13fdb6"
      ).tap { |w| w.set_legal_agreements_to_true }
    end

    it 'recovers the wallet to the correct balance' do
      expect(wallet.get_balance).to eq(BigDecimal("0"))
      wallet.recover
      expect(wallet.get_balance).to eq(BigDecimal("15.0000001"))
    end
  end
end
