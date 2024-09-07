# frozen_string_literal: true

# lib/webcash/helpers.rb
require "bigdecimal"
require "securerandom"
require "base64"
require "digest"

module Webcash
  # Provides helper methods for Webcash.
  module Helpers
    def self.range(start, stop, step = 1)
      return [] if (step.positive? && start >= stop) || (step.negative? && start <= stop)

      result = []
      i = start
      while step.positive? ? i < stop : i > stop
        result << i
        i += step
      end

      result
    end

    def self.chunk_array(array, chunk_size)
      array.each_slice(chunk_size).to_a
    end

    # Check that the amount has no more than a maximum number of decimal places.
    def self.validate_amount_decimals(amount)
      if amount.is_a?(String)
        amount = parse_amount_from_string(amount)
      elsif amount.is_a?(Float)
        amount = BigDecimal(amount.to_s)
      else
        amount = BigDecimal(amount)
      end

      raise RangeError, "Amount precision should be at most 8 decimals." unless amount.scale <= 8

      true
    end

    def self.deserialize_webcash(webcash)
      raise Error, "Unusable format for webcash." unless webcash.include?(":")

      parts = webcash.split(":")
      raise Error, "Don't know how to deserialize this webcash." if parts.length < 2

      amount_raw = parts[0]
      public_or_secret = parts[1]
      value = parts[2]

      raise Error, "Can't deserialize this webcash, value is missing." if value.nil?

      unless %w[public secret].include?(public_or_secret)
        raise Error, "Can't deserialize this webcash, needs to be either public/secret."
      end

      amount = parse_amount_from_string(amount_raw)

      if public_or_secret == "secret"
        Webcash::Secret.new(amount, value)
      else
        Webcash::Public.new(amount, value)
      end
    end

    def self.parse_amount_from_string(amount_raw)
      # If there is a colon in the value, then the amount is going to be on the
      # left hand side.
      part1 = amount_raw.split(":")[0]

      # There can be at most one 'e' in the value, at the beginning.
      count = part1.count("e")
      if count.zero?
        BigDecimal(part1)
      elsif count <= 1
        # should be at the beginning
        raise Error, "Invalid amount format for webcash." unless part1[0] == "e"
        # there needs to be an actual amount
        raise Error, "Invalid amount format for webcash." unless part1 != "e"

        part2 = part1.split("e")[1]
        BigDecimal(part2)

      else
        raise Error, "Invalid amount format for webcash."
      end
    end

    def self.convert_secret_value_to_public_value(secret_value)
      Digest::SHA256.hexdigest(secret_value)
    end

    # Convert from a string amount to a Decimal value.
    def self.string_amount_to_decimal(amount)
      BigDecimal(amount)
    end
    

    # Convert a decimal amount to a string. This is used for representing
    # different webcash when serializing webcash. When the amount is not known,
    # the string should be "?".
    def self.decimal_amount_to_string(amount)
      return "?" if amount.nil?

      if amount.frac.zero?
        amount.to_i.to_s
      else
        # Force 8 decimals and trim trailing zeros
        amount_str = format("%.8f", amount)
        amount_str.sub(/\.?0+$/, "")
      end
    end

    def self.create_webcash_with_random_secret_from_amount(amount)
      random_value = SecureRandom.random_bytes(32)
      "e#{amount.to_s('F')}:secret:#{Base64.strict_encode64(random_value)}"
    end
  end
end
