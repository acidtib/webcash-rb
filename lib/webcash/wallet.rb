# frozen_string_literal: true

# lib/webcash/wallet.rb

require "httparty"
require "json"

module Webcash
  class Wallet
    attr_accessor :version,
                  :legalese,
                  :webcash,
                  :unconfirmed,
                  :log,
                  :master_secret,
                  :walletdepths

    DEFAULT_WALLETDEPTHS = {
      "RECEIVE" => 0,
      "PAY" => 0,
      "CHANGE" => 0,
      "MINING" => 0
    }

    DEFAULT_LEGALESE = { "terms" => nil }

    CHAIN_CODES = {
      "RECEIVE" => 0,
      "PAY" => 1,
      "CHANGE" => 2,
      "MINING" => 3
    }

    API_REPLACE = "https://webcash.org/api/v1/replace"
    API_HEALTHCHECK = "https://webcash.org/api/v1/health_check"

    def initialize(
      version: "1.0",
      legalese: DEFAULT_LEGALESE,
      webcash: [],
      unconfirmed: [],
      log: [],
      master_secret: "",
      walletdepths: DEFAULT_WALLETDEPTHS
    )
      @version = version
      @legalese = legalese
      @webcash = webcash
      @unconfirmed = unconfirmed
      @log = log
      @master_secret = master_secret.empty? ? Webcash::Helpers.generate_random_value(32) : master_secret
      @walletdepths = walletdepths
    end

    # Check that the legal agreements have been agreed to and acknowledged.
    def check_legal_agreements
      @legalese["terms"] == true
    end

    # Set the legal agreements to true
    def set_legal_agreements_to_true
      @legalese["terms"] = true
    end

    # Get all contents of the wallet
    def get_contents
      {
        master_secret: @master_secret,
        walletdepths: @walletdepths,
        webcash: @webcash,
        unconfirmed: @unconfirmed,
        log: @log,
        version: @version,
        legalese: @legalese
      }
    end

    # Calculate the balance based on the webcash in the wallet
    def get_balance
      @webcash
        .map { |n| Webcash::Secret.deserialize(n).amount }
        .reduce(BigDecimal("0")) { |prev, next_val| prev + next_val }
    end

    # Generate the next secret based on chain code and seek value
    def generate_next_secret(chain_code, seek = false)
      walletdepth = seek ? seek : @walletdepths[chain_code]

      master_secret = @master_secret
      master_secret_bytes = Webcash::Helpers.convert_secret_hex_to_bytes(master_secret)

      chain_coded = CHAIN_CODES[chain_code]
      raise ArgumentError, "Invalid chain code" if chain_coded.nil?

      # Tag as byte array
      tag = Webcash::Helpers.sha256_from_array([ 119, 101, 98, 99, 97, 115, 104, 119, 97, 108, 108, 101, 116, 118, 49 ])

      array = []
      tag_numbers = tag.unpack("C*")
      array.concat(tag_numbers)
      array.concat(tag_numbers)
      array.concat(master_secret_bytes)
      array.concat(Webcash::Helpers.long_to_byte_array(chain_coded).reverse)
      array.concat(Webcash::Helpers.long_to_byte_array(walletdepth).reverse)

      new_secret = Webcash::Helpers.sha256_from_array(array)

      new_hex_secret = new_secret.unpack1("H*") # Convert binary data to hex string

      # Update wallet depths if seek is false
      unless seek
        @walletdepths[chain_code] += 1
      end

      new_hex_secret
    end

    # Insert webcash into the wallet. Replace the given webcash with new webcash.
    def insert(webcash, memo = "")
      # Deserialize the given webcash if it's a string
      if webcash.is_a?(String)
        webcash = Webcash::Secret.deserialize(webcash)
      end

      # Create a new secret webcash
      new_webcash = Webcash::Secret.new(webcash.amount, generate_next_secret("RECEIVE"))

      # Check if the legal agreements have been accepted
      unless check_legal_agreements
        raise "User hasn't agreed to the legal terms."
      end

      # Prepare the replacement request body
      replace_request_body = {
        webcashes: [ webcash.to_s ],
        new_webcashes: [ new_webcash.to_s ],
        legalese: @legalese
      }

      # Save the new webcash into the wallet so the value isn't lost if there's a network error
      new_webcash_str = new_webcash.to_s
      @unconfirmed.push(new_webcash_str)

      # Execute the replacement request
      begin
        # Make the POST request using HTTParty
        response = HTTParty.post(API_REPLACE, body: JSON.dump(replace_request_body), headers: { "Content-Type" => "application/json" })

        # Log the response
        puts "After replace API call. Response = #{response.body}"

        # Check if the response was successful
        unless response.success?
          raise "Server returned an error: #{response.body}"
        end

      rescue => e
        # Handle network or other exceptions, log them, and raise
        puts "Could not successfully call replacement API"
        raise e
      end

      # Handle existing webcash
      existing_webcash_str = @webcash.find { |w| w == webcash.to_s }
      if existing_webcash_str
        # Replace existing webcash with new webcash
        @webcash.reject! { |item| item == existing_webcash_str }
      end

      # Remove from unconfirmed
      @unconfirmed.reject! { |item| item == new_webcash_str }

      # Add the new webcash to the wallet
      @webcash.push(new_webcash.to_s)

      # Log the operation
      @log.push({
        type: "insert",
        amount: Webcash::Helpers.decimal_amount_to_string(new_webcash.amount),
        webcash: webcash.to_s,
        new_webcash: new_webcash_str,
        memo: memo,
        timestamp: Time.now.to_i.to_s
      })

      # Return the new webcash
      new_webcash.to_s
    end


    def pay(amount, memo = "")
      amount = BigDecimal(amount.to_s)

      # Check legal agreements
      raise "User hasn't agreed to the legal terms." unless check_legal_agreements

      have_enough = false
      input_webcash = []

      # Try to satisfy the request with a single payment that matches the size
      @webcash.each do |webcash_str|
        webcash = Webcash::Secret.deserialize(webcash_str)
        if webcash.amount >= amount
          input_webcash.push(webcash)
          have_enough = true
          break
        end
      end

      unless have_enough
        running_amount = BigDecimal("0")
        running_webcash = []

        @webcash.each do |webcash_str|
          webcash = Webcash::Secret.deserialize(webcash_str)
          running_amount += webcash.amount
          running_webcash.push(webcash)
          if running_amount >= amount
            input_webcash = running_webcash
            have_enough = true
            break
          end
        end
      end

      unless have_enough
        raise "Wallet does not have enough funds to make the transfer."
      end

      found_amount = input_webcash.sum(&:amount)
      change_amount = found_amount - amount

      new_webcash = []
      if change_amount > BigDecimal("0")
        change_webcash = Webcash::Secret.new(change_amount, generate_next_secret("CHANGE"))
        new_webcash.push(change_webcash.to_s)
      end

      transfer_webcash = Webcash::Secret.new(amount, generate_next_secret("PAY"))
      new_webcash.push(transfer_webcash.to_s)

      # Prepare the replacement request body
      replace_request_body = {
        webcashes: input_webcash.map(&:to_s),
        new_webcashes: new_webcash,
        legalese: @legalese
      }

      # Save the new webcash into the wallet
      @unconfirmed.push(transfer_webcash.to_s)
      @unconfirmed.push(change_webcash.to_s) if change_webcash

      # Execute the replacement request
      begin
        response = HTTParty.post(API_REPLACE, body: JSON.dump(replace_request_body), headers: { "Content-Type" => "application/json" })

        raise "Server returned an error: #{response.body}" unless response.success?
      rescue => e
        puts "Could not successfully call the replacement API"
        raise e
      end

      # Remove the webcash from the wallet
      @webcash.reject! { |item| replace_request_body[:webcashes].include?(item) }
      @unconfirmed.reject! { |item| item == transfer_webcash.to_s || item == change_webcash.to_s }

      # Record change
      if change_webcash
        @webcash.push(change_webcash.to_s)
        @log.push({
          type: "change",
          amount: Webcash::Helpers.decimal_amount_to_string(change_amount),
          webcash: change_webcash.to_s,
          timestamp: Time.now.to_i.to_s
        })
      end

      # Record payment
      @log.push({
        type: "payment",
        amount: Webcash::Helpers.decimal_amount_to_string(transfer_webcash.amount),
        webcash: transfer_webcash.to_s,
        memo: memo,
        timestamp: Time.now.to_i.to_s
      })

      # Return the transfer webcash
      transfer_webcash.to_s
    end

    def process_healthcheck_results(results, webcashes_map = {})
      results.each do |public_webcash, result|
        hashed_value = Webcash::Public.deserialize(public_webcash).hashed_value
        wallet_cash = Webcash::Secret.deserialize(webcashes_map[hashed_value])

        if result["spent"] == false
          # Check the amount.
          result_amount = BigDecimal(result["amount"].to_s)
          if result_amount != wallet_cash.amount
            puts "Wallet was mistaken about amount stored by a certain webcash. Updating."
            @webcash.reject! { |item| item == webcashes_map[hashed_value] }
            @webcash.push(Webcash::Secret.new(result_amount, wallet_cash.secret_value).to_s)
          end
        elsif [ nil, true ].include?(result["spent"])
          # Invalid webcash found. Remove from wallet.
          puts "Removing some webcash."
          @webcash.reject! { |item| item == webcashes_map[hashed_value] }
          @unconfirmed.push(webcashes_map[hashed_value])
        else
          raise "Invalid webcash status: #{result["spent"]}"
        end
      end
    end

    # Check every webcash in the wallet and remove any invalid already-spent
    def check
      webcashes = {}
      @webcash.each do |webcash|
        sk = Webcash::Secret.deserialize(webcash)
        hashed_value = sk.to_public.hashed_value

        # Detect and remove duplicates.
        if webcashes.key?(hashed_value)
          puts "Duplicate webcash detected in wallet, moving it to unconfirmed"
          @unconfirmed.push(webcash)

          # Remove all copies
          @webcash.reject! { |item| item == webcash }

          # Add one copy back for a total of one
          @webcash.push(webcash)

          save if respond_to?(:save)
        end

        # Make a map from the hashed value back to the webcash which can
        # be used for lookups when the server gives a response.
        webcashes[hashed_value] = webcash
      end

      chunks = Webcash::Helpers.chunk_array(@webcash, 25)

      chunks.each do |chunk|
        health_check_request = chunk.map { |webcash| Webcash::Secret.deserialize(webcash).to_public.to_s }

        begin
          response = HTTParty.post(
            API_HEALTHCHECK,
            body: JSON.dump(health_check_request),
            headers: { "Content-Type" => "application/json" }
          )

          response_content = response.body
          if response.code != 200
            raise "Server returned an error: #{response_content}"
          end

          response_data = JSON.parse(response_content)
          results = response_data["results"]

          process_healthcheck_results(results, webcashes)
        rescue => e
          puts "Could not successfully call the healthcheck API"
          raise e
        end
      end
    end

    def recover(gaplimit: 20, sweep_payments: false)
      # Start by healthchecking the contents of the wallet.
      check

      @walletdepths.each do |chain_code, reported_walletdepth|
        current_walletdepth = 0
        last_used_walletdepth = 0
        has_had_webcash = true
        idx = 0

        while has_had_webcash
          puts "Checking gaplimit #{gaplimit} secrets for chainCode #{chain_code}, round #{idx}"

          # Assume this is the last iteration
          has_had_webcash = false

          # Check the next gaplimit number of secrets
          health_check_request = []
          check_webcashes = {}
          walletdepths = {}

          Webcash::Helpers.range(current_walletdepth, current_walletdepth + gaplimit).each do |x|
            secret = generate_next_secret(chain_code, x)
            webcash = Webcash::Secret.new(BigDecimal(1), secret)
            public_webcash = webcash.to_public
            check_webcashes[public_webcash.hashed_value] = webcash
            walletdepths[public_webcash.hashed_value] = x
            health_check_request << public_webcash.to_s
          end

          # Fetch the response from the healthcheck API
          begin
            response = HTTParty.post(
              API_HEALTHCHECK,
              body: JSON.dump(health_check_request),
              headers: { "Content-Type" => "application/json" }
            )

            response_content = response.body
            if response.code != 200
              raise "Server returned an error: #{response_content}"
            end

            response_data = JSON.parse(response_content)
            results = response_data["results"]

            # Use results and check_webcashes to process
            results.each do |public_webcash_str, result|
              public_webcash = Webcash::Public.deserialize(public_webcash_str)
              if result["spent"] != nil
                has_had_webcash = true
                last_used_walletdepth = walletdepths[public_webcash.hashed_value]
              end

              if result["spent"] == false
                swc = check_webcashes[public_webcash.hashed_value]
                swc.amount = BigDecimal(result["amount"])

                if sweep_payments || chain_code != "PAY"
                  unless @webcash.include?(swc.to_s)
                    puts "Recovered webcash: #{Webcash::Helpers.decimal_amount_to_string(swc.amount)}"
                    @webcash.push(swc.to_s)
                  end
                else
                  puts "Found known webcash of amount: #{Webcash::Helpers.decimal_amount_to_string(swc.amount)}"
                end
              end
            end

            if current_walletdepth < reported_walletdepth
              has_had_webcash = true
            end

            if has_had_webcash
              current_walletdepth += gaplimit
            end

            idx += 1
          rescue => e
            puts "Could not successfully call the healthcheck API"
            raise e
          end
        end

        if reported_walletdepth > last_used_walletdepth + 1
          puts "Something may have gone wrong: reported walletdepth was #{reported_walletdepth} but only found up to #{last_used_walletdepth} depth."
        end

        if reported_walletdepth < last_used_walletdepth
          @walletdepths[chain_code] = last_used_walletdepth + 1
        end
      end

      save if respond_to?(:save)
    end
  end
end
