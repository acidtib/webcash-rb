# frozen_string_literal: true

# spec/secret_spec.rb
require "spec_helper"

RSpec.describe Webcash::Secret do
  let(:amount) { BigDecimal("1.0") }
  let(:secret_value) { "feedbeef" }
  let(:hashed_value) { "32549bff6d8404c4d121b589f4d24ac6416ed48c25163e1f08d92d67ca0bb0b3" }

  it "deserializes secret webcash correctly" do
    webcash = Webcash::Secret.deserialize("e100:secret:feedbeef")
    expect(webcash.amount).to eq(BigDecimal("100"))

    webcash = Webcash::Secret.deserialize("e3.003:secret:feedbeef")
    expect(webcash).to eq(Webcash::Secret.new(BigDecimal("3.003"), "feedbeef"))
  end

  it "returns the correct string representation" do
    secret_webcash = Webcash::Secret.new(BigDecimal("1.0"), "feedbeef")
    expect(secret_webcash.to_s).to eq("e1:secret:feedbeef")
  end

  it "initializes secret and public webcash with correct values" do
    secret_webcash = Webcash::Secret.new(amount, secret_value)
    public_webcash = Webcash::Public.new(amount, secret_webcash.to_public.hashed_value)

    expect(secret_webcash.amount).to eq(amount)
    expect(secret_webcash.to_public.amount).to eq(amount)
    expect(secret_webcash.to_public.hashed_value).to eq(hashed_value)
    expect(secret_webcash.to_public.amount).to eq(secret_webcash.amount)
  end

  it "raises an error for invalid amount decimals" do
    expect { Webcash::Secret.new(BigDecimal("3.123456789"), secret_value) }.to raise_error(RangeError)
    expect { Webcash::Public.new(BigDecimal("3.123456789"), secret_value) }.to raise_error(RangeError)
  end
end
