module Api
  module V1
    class ResourcesController < ApiController
      before_action :ensure_json_request
      before_action :set_resource, only: [:show, :create_or_update, :destroy]

      # GET /resources/:id
      # GET /resources/:id.json
      def show
        if @resource
          render json: @resource
        else
          render json: {
            errors: ["Could not find resource with identifier/secondary_identifier: #{identifier}"]
          }, status: :not_found
        end
      end

      # PATCH/PUT /resources/:id
      # PATCH/PUT /resources/:id.json
      def create_or_update
        if @resource.nil?
          @resource = Resource.create(create_or_update_params)
          render json: { resource: @resource }, status: :created
        elsif @resource.update(create_or_update_params)
          render json: { resource: @resource }, status: :ok
        else
          render json: errors(@resource.errors.full_messages), status: :bad_request
        end
      end

      # DELETE /resources/:id
      # DELETE /resources/:id.json
      def destroy
        if @resource.nil? || @resource.destroy
          head :no_content
        else
          render json: errors('Deletion failed.'), status: :bad_request
        end
      end

      private

        def set_resource
          @resource = Resource.find_by_identifier_or_secondary_identifier(params[:id])
        end

        def create_or_update_params
          params.require(:resource).permit(:identifier, :secondary_identifier, :location_uri, :featured_region)
        end
    end
  end
end
