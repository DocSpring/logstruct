# typed: true
# frozen_string_literal: true

class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}

  # Add callbacks to test logging
  after_create :log_creation
  after_update :log_update

  private

  def log_creation
    Rails.logger.info("User created with ID: #{id} and email: #{email}")
  end

  def log_update
    # Standard Rails logging with context
    changed_attrs = previous_changes.keys.join(", ")
    Rails.logger.info("User #{id} updated. Changed attributes: #{changed_attrs}")
  end
end
