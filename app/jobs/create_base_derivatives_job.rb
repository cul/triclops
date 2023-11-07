# frozen_string_literal: true

class CreateBaseDerivativesJob < ApplicationJob
  queue_as Triclops::Queues::CREATE_BASE_DERIVATIVES

  def perform(identifier)
    resource = Resource.find_by(identifier: identifier)
    return if resource.nil?

    resource.with_lock do
      # Immediately return if this resource is already ready OR if it is currently being processed.
      return if resource.ready? || resource.processing?

      # We're moving forward with processing, so we'll mark this resource as processing.
      resource.processing!
    end

    resource.generate_base_derivatives
    resource.generate_commonly_requested_derivatives

    resource.ready!
  rescue StandardError, SyntaxError => e
    # NOTE: An uncaught SyntaxError in later-called code would result in a derivative_request
    # that's incorrectly stuck with a "processing" status, so that's why we catch (and re-throw)
    # SyntaxErrors in this block too.
    handle_and_rethrow_unexpected_error(resource, e)
  end

  def handle_and_rethrow_unexpected_error(resource, err)
    resource.update!(
      status: :failure,
      error_message: "#{err.message}\n#{err.backtrace.join("\n\t")}"
    )
    # And re-raise the exception so that we don't hide it
    raise err
  end
end
