# frozen_string_literal: true

# spec/public_spec.rb
require "spec_helper"

RSpec.describe Webcash::Public do
  let(:amount) { BigDecimal("1.0") }
  let(:secret_value) { "feedbeef" }
  let(:hashed_value) { "32549bff6d8404c4d121b589f4d24ac6416ed48c25163e1f08d92d67ca0bb0b3" }

  it "deserializes public webcash correctly" do
    webcash = Webcash::Public.deserialize("e100:public:feedbeef")
    expect(webcash.amount).to eq(BigDecimal("100"))

    webcash = Webcash::Public.deserialize("e15.05:public:feedbeef")
    expect(webcash).to eq(Webcash::Public.new(BigDecimal("15.05"), "feedbeef"))
  end

  it "returns the correct string representation" do
    public_webcash = Webcash::Public.new(BigDecimal("1.0"), "feedbeef")
    expect(public_webcash.to_s).to eq("e1:public:feedbeef")
  end
end
