# typed: true

module RailsStructuredLogging::ActionMailer::ErrorHandling
  # Tell Sorbet that we are including this module into ActionMailer::Base
  # and we have the rescue_from class methods available
  requires_ancestor { ::ActionMailer::Base }
  extend ::ActiveSupport::Rescuable::ClassMethods
end
