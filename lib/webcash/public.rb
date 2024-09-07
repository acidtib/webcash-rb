# frozen_string_literal: true

# lib/webcash/public.rb

module Webcash
  class Public
    attr_reader :amount, :hashed_value

    def initialize(amount, hashed_value)
      Webcash::Helpers.validate_amount_decimals(amount)
      @amount = amount
      @hashed_value = hashed_value
    end

    def self.deserialize(webcash)
      Webcash::Helpers.deserialize_webcash(webcash)
    end

    def is_equal(other)
      if other.is_a?(Webcash::Secret)
        return true if @hashed_value == other.to_public.hashed_value
      elsif other.is_a?(Webcash::Public)
        return true if @hashed_value == other.hashed_value
      end

      false
    end

    def to_s
      "e#{@amount.to_s('F').sub(/\.0+$/, '')}:public:#{@hashed_value}"
    end

    def ==(other)
      other.is_a?(Webcash::Public) && @amount == other.amount && @hashed_value == other.hashed_value
    end
  end
end
