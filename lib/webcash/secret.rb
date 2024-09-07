# frozen_string_literal: true

# lib/webcash/secret.rb

module Webcash
  class Secret
    attr_accessor :amount
    attr_reader :amount, :secret_value

    def initialize(amount, secret_value)
      Webcash::Helpers.validate_amount_decimals(amount)
      @amount = amount
      @secret_value = secret_value
    end

    def self.deserialize(webcash)
      Webcash::Helpers.deserialize_webcash(webcash)
    end

    def self.from_amount(amount)
      Webcash::Secret.deserialize(Webcash::Helpers.create_webcash_with_random_secret_from_amount(amount))
    end

    def is_equal(other)
      if other.is_a?(Webcash::Secret)
        return true if @secret_value == other.secret_value
      elsif other.is_a?(Webcash::Public)
        return true if to_public.hashed_value == other.hashed_value
      end

      false
    end

    def to_s
      "e#{@amount.to_s('F').sub(/\.0+$/, '')}:secret:#{@secret_value}"
    end

    def ==(other)
      other.is_a?(Webcash::Secret) && @amount == other.amount && @secret_value == other.secret_value
    end

    def to_public
      hashed_value = Webcash::Helpers.convert_secret_value_to_public_value(@secret_value)
      Webcash::Public.new(@amount, hashed_value)
    end
  end
end
