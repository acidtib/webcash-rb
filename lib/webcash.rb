# frozen_string_literal: true

# lib/webcash.rb
require_relative "webcash/version"
require_relative "webcash/helpers"
require_relative "webcash/public"
require_relative "webcash/secret"
require_relative "webcash/wallet"

module Webcash
  class Error < StandardError; end
end
