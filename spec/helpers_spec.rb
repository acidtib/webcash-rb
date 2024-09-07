# frozen_string_literal: true

# spec/helpers_spec.rb
require "spec_helper"

RSpec.describe Webcash::Helpers do
  describe ".range" do
    it "returns an array of numbers from start to stop" do
      expect(described_class.range(0, 5)).to eq([ 0, 1, 2, 3, 4 ])
      expect(described_class.range(5, 10)).to eq([ 5, 6, 7, 8, 9 ])
    end
  end

  describe ".chunk_array" do
    it "chunks the array into arrays of size chunk_size" do
      expect(described_class.chunk_array([ 1, 2, 3, 4, 5 ], 1)).to eq([ [ 1 ], [ 2 ], [ 3 ], [ 4 ], [ 5 ] ])
      expect(described_class.chunk_array([ 1, 2, 3, 4, 5, 6 ], 3)).to eq([ [ 1, 2, 3 ], [ 4, 5, 6 ] ])
      expect(described_class.chunk_array([ 1, 2, 3, 4, 5, 6 ], 5)).to eq([ [ 1, 2, 3, 4, 5 ], [ 6 ] ])
    end
  end

  describe ".validate_amount_decimals" do
    it 'returns true for amounts with 0 to 8 decimal places' do
      expect(described_class.validate_amount_decimals(1)).to be(true)
      expect(described_class.validate_amount_decimals(1.0)).to be(true)
      expect(described_class.validate_amount_decimals(1.00)).to be(true)
      expect(described_class.validate_amount_decimals(1.000)).to be(true)
      expect(described_class.validate_amount_decimals(1.0000)).to be(true)
      expect(described_class.validate_amount_decimals(1.00000)).to be(true)
      expect(described_class.validate_amount_decimals(1.000000)).to be(true)
      expect(described_class.validate_amount_decimals(1.0000000)).to be(true)
      expect(described_class.validate_amount_decimals(1.00000000)).to be(true)
      expect(described_class.validate_amount_decimals(1.000000000000000000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.0)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.00)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.0000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.00000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.000000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.0000000)).to be(true)
      expect(described_class.validate_amount_decimals(100000000.00000000)).to be(true)
    end

    it 'raises a RangeError for amounts with more than 8 decimal places' do
      expect { described_class.validate_amount_decimals(1.000000001) }.to raise_error(RangeError)

      expect { described_class.validate_amount_decimals(1.0000000001) }.to raise_error(RangeError)

      expect { described_class.validate_amount_decimals(1.000000000000999999999) }.to raise_error(RangeError)
    end
  end

  describe ".deserialize_webcash" do
    it 'deserializes secret webcash' do
      result = described_class.deserialize_webcash('e100:secret:feedbeef')
        expect(result).to be_a(Webcash::Secret)
        expect(result.secret_value).to eq('feedbeef')
        expect(result.amount).to eq(BigDecimal('100'))

        result = described_class.deserialize_webcash('e1:secret:feedbeef')
        expect(result).to be_a(Webcash::Secret)
        expect(result.secret_value).to eq('feedbeef')
        expect(result.amount).to eq(BigDecimal('1'))

        result = described_class.deserialize_webcash('1:secret:feedbeef')
        expect(result).to be_a(Webcash::Secret)
        expect(result.secret_value).to eq('feedbeef')
        expect(result.amount).to eq(BigDecimal('1'))
    end

    it 'deserializes public webcash' do
      result = described_class.deserialize_webcash('e1:public:feedbeef')
      expect(result).to be_a(Webcash::Public)
      expect(result.hashed_value).to eq('feedbeef')
      expect(result.amount).to eq(BigDecimal('1'))

      result = described_class.deserialize_webcash('e100:public:feedbeef')
      expect(result).to be_a(Webcash::Public)
      expect(result.hashed_value).to eq('feedbeef')
      expect(result.amount).to eq(BigDecimal('100'))
    end

    it 'raises an error for unusable formats' do
      expect { described_class.deserialize_webcash('invalid_format') }.to raise_error(StandardError, 'Unusable format for webcash.')
    end

    it 'raises an error for unknown deserialization formats' do
      expect { described_class.deserialize_webcash('e100:unknown:feedbeef') }.to raise_error(StandardError, "Can't deserialize this webcash, needs to be either public/secret.")
    end

    it 'raises an error if there are not enough parts' do
      expect { described_class.deserialize_webcash('e100:secret') }.to raise_error(StandardError, "Can't deserialize this webcash, value is missing.")
    end
  end

  describe ".parse_amount_from_string" do
    it 'parses valid amounts with "e" notation' do
      expect(described_class.parse_amount_from_string("e1")).to eq(BigDecimal("1"))
      expect(described_class.parse_amount_from_string("e500")).to eq(BigDecimal("500"))
      expect(described_class.parse_amount_from_string("e1.05")).to eq(BigDecimal("1.05"))
    end

    it 'parses valid amounts without "e" notation' do
      expect(described_class.parse_amount_from_string("100:secret:feedbeef")).to eq(BigDecimal("100"))
      expect(described_class.parse_amount_from_string("e100:secret:feedbeef")).to eq(BigDecimal("100"))
    end

    it 'raises an error for invalid formats with "e"' do
      expect { described_class.parse_amount_from_string("e500e") }.to raise_error(StandardError, "Invalid amount format for webcash.")
      expect { described_class.parse_amount_from_string("e500.00e") }.to raise_error(StandardError, "Invalid amount format for webcash.")
      expect { described_class.parse_amount_from_string("e100.00e") }.to raise_error(StandardError, "Invalid amount format for webcash.")
      expect { described_class.parse_amount_from_string("ee100") }.to raise_error(StandardError, "Invalid amount format for webcash.")
    end
  end

  describe ".create_webcash_with_random_secret_from_amount" do
    it "creates a valid webcash string with the correct amount" do
      amount = BigDecimal("100.0")
      webcash_str = described_class.create_webcash_with_random_secret_from_amount(amount)

      # Ensure the generated string matches the expected pattern
      expect(webcash_str).to match(/e#{amount.to_s('F')}:secret:[A-Za-z0-9+\/=]{32}/)

      # Deserialize the webcash string and check the amount
      webcash = Webcash::Secret.deserialize(webcash_str)
      expect(webcash.amount).to eq(amount)
    end
  end

  describe ".string_amount_to_decimal" do
    it "converts a string amount to a BigDecimal value" do
      result = described_class.string_amount_to_decimal("1")
      expected = BigDecimal("1")

      expect(result).to eq(expected)
    end
  end

  describe ".decimal_amount_to_string" do
    it "returns '1' when amount is 1.0" do
      result = described_class.decimal_amount_to_string(BigDecimal("1.0"))
      expect(result).to eq("1")
    end

    it "returns '1.099' when amount is 1.099" do
      result = described_class.decimal_amount_to_string(BigDecimal("1.099"))
      expect(result).to eq("1.099")
    end

    it "returns '0.0000001' when amount is 0.00000010" do
      result = described_class.decimal_amount_to_string(BigDecimal("0.00000010"))
      expect(result).to eq("0.0000001")
    end

    it "returns '?' when amount is nil" do
      result = described_class.decimal_amount_to_string(nil)
      expect(result).to eq("?")
    end
  end

  describe '.hex_to_padded_bytes' do
    it 'converts hex to padded bytes' do
      expect(described_class.hex_to_padded_bytes("0xfeedbeef")).to eq([ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xfe, 0xed, 0xbe, 0xef ])
    end
  end

  describe '.hex_to_bytes' do
    it 'converts hex string to bytes' do
      expect(described_class.hex_to_bytes("0xfeedbeef")).to eq([ 254, 237, 190, 239 ])
    end
  end

  describe '.padded_bytes' do
    it 'pads bytes array to the target length' do
      expect(described_class.padded_bytes([ 0 ], 8)).to eq([ 0, 0, 0, 0, 0, 0, 0, 0 ])
      expect(described_class.padded_bytes([ 1 ], 8)).to eq([ 0, 0, 0, 0, 0, 0, 0, 1 ])
    end

    it 'raises an error if bytes array is too large' do
      expect { described_class.padded_bytes([ 1 ] * 33, 32) }.to raise_error(RuntimeError, /Can only handle up to 32 bytes/)
    end
  end

  describe '.long_to_byte_array' do
    it 'converts a number to a byte array' do
      expect(described_class.long_to_byte_array(1).reverse).to eq([ 0, 0, 0, 0, 0, 0, 0, 1 ])
      expect(described_class.long_to_byte_array(1234).reverse).to eq([ 0, 0, 0, 0, 0, 0, 4, 210 ])
      expect(described_class.long_to_byte_array(100000000).reverse).to eq([ 0, 0, 0, 0, 5, 245, 225, 0 ])
    end
  end

  describe '.assert_is_array' do
    it 'does not raise an error for a valid number array' do
      expect { described_class.assert_is_array([ 1, 2, 3 ]) }.not_to raise_error
    end

    it 'raises an error for non-array inputs' do
      expect { described_class.assert_is_array('string') }.to raise_error(RuntimeError, /This method only supports number arrays but input was: string/)
    end

    it 'raises an error for arrays containing non-integer elements' do
      expect { described_class.assert_is_array([ 1, 2, 'string' ]) }.to raise_error(RuntimeError, /This method only supports number arrays but input was: \[1, 2, "string"\]/)
    end
  end

  describe '.sha256_from_array' do
    it 'computes SHA256 hash from a number array' do
      # Example input and expected output
      input = [ 1, 2, 3, 4 ]
      expected_output = Digest::SHA256.digest([ 1, 2, 3, 4 ].pack('C*'))

      expect(described_class.sha256_from_array(input)).to eq(expected_output)
    end

    it 'raises an error for invalid inputs' do
      expect { described_class.sha256_from_array('string') }.to raise_error(RuntimeError, /This method only supports number arrays but input was: string/)
      expect { described_class.sha256_from_array([ 1, 2, 'string' ]) }.to raise_error(RuntimeError, /This method only supports number arrays but input was: \[1, 2, "string"\]/)
    end
  end
end
