# typed: true
# frozen_string_literal: true

class TestMailer < ApplicationMailer
  def test_email_with_ids(account, user)
    @account = account
    @user = user
    mail(to: "test@example.com", subject: "Test Email")
  end

  def test_email_with_organization(organization)
    @organization = organization
    mail(to: "test@example.com", subject: "Test Email")
  end
end
