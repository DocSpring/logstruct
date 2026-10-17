# typed: strict
# frozen_string_literal: true

module LogStruct
  module Integrations
    module Sidekiq
      # Sidekiq server middleware that adds the running job's ID and class to every line
      # logged while it runs, in the same `ctx` field as Sidekiq's own log lines. A query
      # on ctx.jid then returns every line for one job run.
      class JobContextMiddleware
        extend T::Sig

        sig do
          params(
            job_instance: T.untyped,
            job_hash: T::Hash[String, T.untyped],
            queue: String,
            block: T.proc.returns(T.untyped)
          ).returns(T.untyped)
        end
        def call(job_instance, job_hash, queue, &block)
          context = {
            jid: job_hash["jid"],
            # Same precedence as Sidekiq's own context, so ActiveJob jobs show their class
            class: job_hash["display_class"] || job_hash["wrapped"] || job_hash["class"]
          }
          ::SemanticLogger.named_tagged(sidekiq_context: context, &block)
        end
      end
    end
  end
end
