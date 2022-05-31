class ApiController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: errors('Not Found'), status: :not_found
  end

  private

    # Generates JSON with errors
    #
    # @param String|Array json response describing errors
    def errors(errors)
      { errors: Array.wrap(errors).map { |e| { title: e } } }
    end
end
