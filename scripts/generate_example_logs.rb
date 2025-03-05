#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "json"
require "time"
require "securerandom"
require "optparse"
require "fileutils"

# Get script options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: generate_example_logs.rb [options]"

  opts.on("-o", "--output PATH", "Output directory for generated logs") do |path|
    options[:output_dir] = path
  end

  opts.on("-n", "--count NUMBER", Integer, "Number of each log type to generate") do |count|
    options[:count] = count
  end

  opts.on("-f", "--format FORMAT", %w[json yaml ruby], "Output format (json, yaml, ruby)") do |format|
    options[:format] = format
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

# Set defaults
options[:output_dir] ||= "site/public/example_logs"
options[:count] ||= 1
options[:format] ||= "json"

# Make sure the output directory exists
FileUtils.mkdir_p(options[:output_dir])

# Helper class to generate realistic data for logs
class LogDataGenerator
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

  def initialize
    @user_ids = (1..100).to_a
    @job_ids = 20.times.map { SecureRandom.hex(12) }
    @email_hashes = 20.times.map { SecureRandom.hex(6) }
  end

  def random_timestamp(range_in_days = 7)
    Time.now - rand(range_in_days * 24 * 60 * 60)
  end

  def random_email(filtered: false)
    if filtered
      "[EMAIL:#{@email_hashes.sample}]"
    else
      "#{FIRST_NAMES.sample.downcase}.#{LAST_NAMES.sample.downcase}@#{DOMAINS.sample}"
    end
  end

  def random_phone(filtered: false)
    filtered ? "[PHONE]" : "+1#{rand(100..999)}#{rand(100..999)}#{rand(1000..9999)}"
  end

  def random_credit_card(filtered: false)
    filtered ? "[CREDIT_CARD]" : "#{rand(1000..9999)}-#{rand(1000..9999)}-#{rand(1000..9999)}-#{rand(1000..9999)}"
  end

  def random_password(filtered: false)
    filtered ? "[FILTERED]" : "p@ssw0rd#{rand(100..999)}"
  end

  def random_ip(filtered: false)
    filtered ? "[IP]" : IP_ADDRESSES.sample
  end

  def random_path
    "#{PATHS.sample}/#{rand(1..100)}"
  end

  def random_user_id
    @user_ids.sample
  end

  def random_job_id
    @job_ids.sample
  end

  def random_duration
    rand(10.0..3000.0).round(2)
  end

  def random_backtrace
    [
      "app/controllers/#{CONTROLLERS.sample.underscore}:#{rand(10..200)}:in `#{ACTIONS.sample}'",
      "app/models/user.rb:#{rand(10..200)}:in `process_data'",
      "app/services/data_processor.rb:#{rand(10..200)}:in `call'"
    ]
  end

  def random_job_args
    [
      random_user_id,
      { action: %w[process update import export].sample },
      random_email(filtered: true),
      { password: random_password(filtered: true) }
    ].sample(rand(1..3))
  end

  def random_file_metadata
    {
      filename: FILE_NAMES.sample,
      content_type: FILE_TYPES.sample,
      size: rand(1000..10_000_000)
    }
  end

  # Specific log generators for each log type
  def generate_request_log
    {
      ts: random_timestamp.iso8601,
      src: "rails",
      evt: "req",
      lvl: "info",
      path: random_path,
      method: HTTP_METHODS.sample,
      controller: CONTROLLERS.sample,
      action: ACTIONS.sample,
      status: STATUS_CODES.sample,
      duration_ms: random_duration,
      ip: random_ip,
      params: {
        id: rand(1..1000),
        page: rand(1..10),
        per_page: [10, 25, 50, 100].sample
      }
    }
  end

  def generate_job_log
    {
      ts: random_timestamp.iso8601,
      src: "job",
      evt: ["start", "process", "complete", "error"].sample,
      lvl: "info",
      job_id: random_job_id,
      job_class: JOB_CLASSES.sample,
      queue: ["default", "mailers", "urgent", "low"].sample,
      args: random_job_args,
      duration_ms: random_duration
    }
  end

  def generate_mailer_log
    {
      ts: random_timestamp.iso8601,
      src: "mailer",
      evt: ["deliver", "error"].sample,
      lvl: "info",
      mailer: MAILER_CLASSES.sample,
      action: MAILER_ACTIONS.sample,
      to: random_email(filtered: true),
      subject: "Your account information",
      duration_ms: random_duration
    }
  end

  def generate_error_log
    {
      ts: random_timestamp.iso8601,
      src: ["rails", "job", "mailer", "security"].sample,
      evt: "error",
      lvl: "error",
      error: ERROR_TYPES.sample,
      message: ERROR_MESSAGES.sample,
      backtrace: random_backtrace
    }
  end

  def generate_security_log
    {
      ts: random_timestamp.iso8601,
      src: "security",
      evt: ["ip_spoof", "csrf_violation", "blocked_host"].sample,
      lvl: "error",
      client_ip: random_ip(filtered: true),
      path: random_path,
      method: HTTP_METHODS.sample
    }
  end

  def generate_shrine_log
    {
      ts: random_timestamp.iso8601,
      src: "shrine",
      evt: ["upload", "download", "delete"].sample,
      lvl: "info",
      storage: STORAGE_SERVICES.sample,
      file_id: "uploads/#{SecureRandom.hex(8)}.jpg",
      size: rand(1000..10_000_000),
      mime_type: FILE_TYPES.sample,
      duration_ms: random_duration
    }
  end

  def generate_activestorage_log
    {
      ts: random_timestamp.iso8601,
      src: "storage",
      evt: ["download", "upload", "delete"].sample,
      lvl: "info",
      service: STORAGE_SERVICES.sample,
      key: "#{SecureRandom.hex(8)}.jpg",
      checksum: "sha256:#{SecureRandom.hex(16)}",
      duration_ms: random_duration
    }
  end

  def generate_sidekiq_log
    {
      ts: random_timestamp.iso8601,
      src: "sidekiq",
      evt: ["process", "error"].sample,
      lvl: "info",
      pid: rand(1000..60000),
      tid: SecureRandom.hex(4),
      job_id: SecureRandom.hex(12),
      class: JOB_CLASSES.sample,
      queue: ["default", "mailers", "urgent", "low"].sample,
      args: random_job_args,
      duration_ms: random_duration,
      status: ["success", "failure", "retry"].sample,
      retry_count: rand(0..5)
    }
  end

  # Generate examples of all log types
  def generate_all_examples(count = 1)
    examples = {
      request: count.times.map { generate_request_log },
      job: count.times.map { generate_job_log },
      mailer: count.times.map { generate_mailer_log },
      error: count.times.map { generate_error_log },
      security: count.times.map { generate_security_log },
      shrine: count.times.map { generate_shrine_log },
      activestorage: count.times.map { generate_activestorage_log },
      sidekiq: count.times.map { generate_sidekiq_log }
    }

    # Add a complete sequence for a job (enqueue -> process -> complete)
    if count > 0
      job_id = SecureRandom.hex(12)
      job_class = JOB_CLASSES.sample
      queue = ["default", "mailers", "urgent", "low"].sample
      args = random_job_args
      
      job_sequence = []
      
      # Enqueue
      enqueue_time = Time.now - rand(60..300)
      job_sequence << {
        ts: enqueue_time.iso8601,
        src: "job",
        evt: "enqueue",
        lvl: "info",
        job_id: job_id,
        job_class: job_class,
        queue: queue,
        args: args
      }
      
      # Process
      process_time = enqueue_time + rand(1..10)
      job_sequence << {
        ts: process_time.iso8601,
        src: "job",
        evt: "process",
        lvl: "info",
        job_id: job_id,
        job_class: job_class,
        queue: queue,
        args: args,
        status: "processing"
      }
      
      # Complete
      complete_time = process_time + rand(1..30)
      duration = ((complete_time - process_time) * 1000).round(2)
      job_sequence << {
        ts: complete_time.iso8601,
        src: "job",
        evt: "complete",
        lvl: "info",
        job_id: job_id,
        job_class: job_class,
        queue: queue,
        args: args,
        status: "success",
        duration_ms: duration
      }
      
      examples[:job_sequence] = job_sequence
    end

    examples
  end
end

# Generate the logs
generator = LogDataGenerator.new
examples = generator.generate_all_examples(options[:count])

# Output the examples in the requested format
examples.each do |type, logs|
  case options[:format]
  when "json"
    file_path = File.join(options[:output_dir], "#{type}.json")
    File.write(file_path, JSON.pretty_generate(logs))
    puts "Generated #{logs.size} #{type} log examples to #{file_path}"
  when "yaml"
    require "yaml"
    file_path = File.join(options[:output_dir], "#{type}.yml")
    File.write(file_path, logs.to_yaml)
    puts "Generated #{logs.size} #{type} log examples to #{file_path}"
  when "ruby"
    file_path = File.join(options[:output_dir], "#{type}.rb")
    File.write(file_path, "[\n  " + logs.map { |log| log.inspect }.join(",\n  ") + "\n]")
    puts "Generated #{logs.size} #{type} log examples to #{file_path}"
  end
end

# Also generate a combined examples file for easy use
all_examples = examples.transform_values { |logs| logs.first }
combined_file_path = File.join(options[:output_dir], "examples.json")
File.write(combined_file_path, JSON.pretty_generate(all_examples))
puts "Generated combined examples to #{combined_file_path}"

# Generate a homepage log scroller sample
log_scroller_samples = []
examples.each do |type, logs|
  next if type == :job_sequence # Skip the special sequence
  log_scroller_samples << logs.first if logs.any?
end

log_scroller_file_path = File.join(options[:output_dir], "log_scroller_samples.json")
File.write(log_scroller_file_path, JSON.pretty_generate(log_scroller_samples.shuffle))
puts "Generated log scroller samples to #{log_scroller_file_path}"