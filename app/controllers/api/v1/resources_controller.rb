module Api
  module V1
    class ResourcesController < ApiController
      before_action :set_resource_or_handle_not_found, only: [:show, :update, :destroy]

      # GET /resources/:id
      # GET /resources/:id.json
      def show
        render json: @resource
      end

      # POST /resources
      # POST /resources.json
      def create
        @resource = Resource.new(create_or_update_params)

        if @resource.save
          render json: { resource: @resource }, status: :created
        else
          render json: errors(@resource.errors.full_messages), status: :bad_request
        end
      end

      # PATCH/PUT /resources/:id
      # PATCH/PUT /resources/:id.json
      def update
        if @resource.update(create_or_update_params)
          render json: { resource: @resource }, status: :ok
        else
          render json: errors(@resource.errors.full_messages), status: :bad_request
        end
      end

      # DELETE /resources/:id
      # DELETE /resources/:id.json
      def destroy
        if @resource.destroy
          head :no_content
        else
          render json: errors('Deleting was unsuccessful.'), status: :bad_request
        end
      end

      private

        def set_resource_or_handle_not_found
          identifier = params[:id]
          return if (
            @resource = Resource.find_by(identifier: identifier) ||
              Resource.find_by(secondary_identifier: identifier)
          )

          render json: {
            errors: ["Could not find resource with identifier/secondary_identifier: #{identifier}"]
          }, status: :not_found
        end

        def create_or_update_params
          params.require(:resource).permit(:identifier, :secondary_identifier, :location_uri, :featured_region)
        end
    end
  end
end
