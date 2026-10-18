# typed: true
# frozen_string_literal: true

# The app's own error pages, for config.exceptions_app = routes (ErrorPagesTest turns them on). Rails sends the
# request here as GET /<status>.
class ErrorsController < ApplicationController
  def show
    status = request.path_info.delete_prefix("/").to_i
    render json: {status: status}, status: status
  end
end
