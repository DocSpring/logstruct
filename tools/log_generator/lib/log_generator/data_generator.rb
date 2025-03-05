# typed: strict
# frozen_string_literal: true

module LogStruct
  module Tools
    class LogGenerator
      # Generates random data for log entries with seed support for deterministic generation
      class DataGenerator
        attr_reader :random

        FIRST_NAMES = %w[James Mary John Patricia Robert Jennifer Michael Linda William Elizabeth]
        LAST_NAMES = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez]
        DOMAINS = %w[example.com gmail.com outlook.com icloud.com company.org]
        HTTP_METHODS = %w[GET POST PUT PATCH DELETE]
        CONTROLLERS = %w[UsersController PostsController CommentsController SessionsController AdminController]
        ACTIONS = %w[index show create update destroy]
        PATHS = %w[/users /posts /comments /login /dashboard /admin /settings /profile]
        JOB_CLASSES = %w[EmailDigestJob ImageProcessingJob ReportGenerationJob NotificationJob DataExportJob ImportJob]
        MAILER_CLASSES = %w[UserMailer NotificationMailer AdminMailer MarketingMailer SystemMailer]
        MAILER_ACTIONS = %w[welcome confirmation password_reset weekly_digest invoice notification]
        ERROR_TYPES = %w[NoMethodError ArgumentError RuntimeError TypeError NameError]
        ERROR_MESSAGES = [
          "undefined method for nil:NilClass",
          "wrong number of arguments (given 2, expected 1)",
          "unexpected token",
          "invalid value for Integer()",
          "uninitialized constant",
          "timeout error connecting to service",
          "database connection failed"
        ]
        STATUS_CODES = [200, 201, 204, 301, 302, 400, 401, 403, 404, 422, 500]
        FILE_TYPES = %w[image/jpeg image/png application/pdf text/csv text/plain]
        FILE_NAMES = %w[profile.jpg document.pdf report.csv data.xlsx avatar.png]
        STORAGE_SERVICES = %w[s3 google cloud_storage disk local]
        IP_ADDRESSES = ["192.168.1.1", "10.0.0.123", "172.16.254.1", "8.8.8.8", "1.1.1.1"]

        # Initialize with an optional seed for deterministic generation
        # @param seed [Integer, nil] Optional random seed for deterministic output
        def initialize(seed = nil)
          # Use the provided seed or generate a random one
          @seed = seed || Random.new_seed
          @random = Random.new(@seed)
          
          # Generate consistent sets of IDs and hashes using our seeded random
          @user_ids = (1..100).to_a.shuffle(random: @random)
          @job_ids = 20.times.map { generate_hex(12) }
          @email_hashes = 20.times.map { generate_hex(6) }
          
          # Current timestamp for the base of all generated times
          @base_time = Time.now
        end
        
        # Returns the seed used for this generator
        # @return [Integer] The random seed
        def seed
          @seed
        end
        
        # Generate a deterministic timestamp
        # @param range_in_days [Integer] Range of days to go back from base time
        # @return [Time] A random time within the range
        def random_timestamp(range_in_days = 7)
          @base_time - @random.rand(range_in_days * 24 * 60 * 60)
        end

        # Generate a random email address, either filtered or plain
        # @param filtered [Boolean] Whether to return a filtered version
        # @return [String] An email address
        def random_email(filtered: false)
          if filtered
            "[EMAIL:#{@email_hashes.sample(random: @random)}]"
          else
            "#{FIRST_NAMES.sample(random: @random).downcase}.#{LAST_NAMES.sample(random: @random).downcase}@#{DOMAINS.sample(random: @random)}"
          end
        end

        # Generate a random phone number, either filtered or plain
        # @param filtered [Boolean] Whether to return a filtered version
        # @return [String] A phone number
        def random_phone(filtered: false)
          filtered ? "[PHONE]" : "+1#{@random.rand(100..999)}#{@random.rand(100..999)}#{@random.rand(1000..9999)}"
        end

        # Generate a random credit card, either filtered or plain
        # @param filtered [Boolean] Whether to return a filtered version
        # @return [String] A credit card number
        def random_credit_card(filtered: false)
          filtered ? "[CREDIT_CARD]" : "#{@random.rand(1000..9999)}-#{@random.rand(1000..9999)}-#{@random.rand(1000..9999)}-#{@random.rand(1000..9999)}"
        end

        # Generate a random password, either filtered or plain
        # @param filtered [Boolean] Whether to return a filtered version
        # @return [String] A password
        def random_password(filtered: false)
          filtered ? "[FILTERED]" : "p@ssw0rd#{@random.rand(100..999)}"
        end

        # Generate a random IP address, either filtered or plain
        # @param filtered [Boolean] Whether to return a filtered version
        # @return [String] An IP address
        def random_ip(filtered: false)
          filtered ? "[IP]" : IP_ADDRESSES.sample(random: @random)
        end

        # Generate a random path
        # @return [String] A path
        def random_path
          "#{PATHS.sample(random: @random)}/#{@random.rand(1..100)}"
        end

        # Get a random user ID
        # @return [Integer] A user ID
        def random_user_id
          @user_ids.sample(random: @random)
        end

        # Get a random job ID
        # @return [String] A job ID
        def random_job_id
          @job_ids.sample(random: @random)
        end

        # Generate a random duration in milliseconds
        # @return [Float] A duration in milliseconds
        def random_duration
          @random.rand(10.0..3000.0).round(2)
        end

        # Generate a random backtrace
        # @return [Array<String>] A backtrace
        def random_backtrace
          [
            "app/controllers/#{CONTROLLERS.sample(random: @random).downcase.sub('controller', '')}:#{@random.rand(10..200)}:in `#{ACTIONS.sample(random: @random)}'",
            "app/models/user.rb:#{@random.rand(10..200)}:in `process_data'",
            "app/services/data_processor.rb:#{@random.rand(10..200)}:in `call'"
          ]
        end

        # Generate random job arguments
        # @return [Array] An array of job arguments
        def random_job_args
          [
            random_user_id,
            { "action" => %w[process update import export].sample(random: @random) },
            random_email(filtered: true),
            { "password" => random_password(filtered: true) }
          ].sample(@random.rand(1..3), random: @random)
        end

        # Generate random file metadata
        # @return [Hash] File metadata
        def random_file_metadata
          {
            filename: FILE_NAMES.sample(random: @random),
            content_type: FILE_TYPES.sample(random: @random),
            size: @random.rand(1000..10_000_000)
          }
        end
        
        # Random choice from array with deterministic result
        # @param array [Array] Array to choose from
        # @return [Object] A random element from the array
        def choice(array)
          array.sample(random: @random)
        end
        
        # Random integer in range with deterministic result
        # @param min [Integer] Minimum value
        # @param max [Integer] Maximum value
        # @return [Integer] A random integer in the range
        def rand_int(min, max)
          @random.rand(min..max)
        end
        
        # Random float in range with deterministic result
        # @param min [Float] Minimum value
        # @param max [Float] Maximum value
        # @param decimals [Integer] Number of decimal places
        # @return [Float] A random float in the range
        def rand_float(min, max, decimals = 2)
          (@random.rand(min..max)).round(decimals)
        end
        
        # Generate a random hexadecimal string with deterministic result
        # @param length [Integer] Length of the string in bytes
        # @return [String] A random hexadecimal string
        def generate_hex(length)
          length.times.map { @random.rand(16).to_s(16) }.join
        end
      end
    end
  end
end