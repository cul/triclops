module Api
  module V1
    class ResourcesController < ApiController
      before_action :ensure_json_request
      before_action :set_resource, only: [:show, :update, :destroy]

      # GET /resources/:id
      # GET /resources/:id.json
      def show
        render json: @resource
      end

      # POST /resources
      # POST /resources.json
      def create
        @resource = Resource.new(create_params)

        if @resource.save
          render json: { resource: @resource }, status: :created
        else
          render json: errors(@resource.errors.full_messages), status: :bad_request
        end
      end

      # PATCH/PUT /resources/:id
      # PATCH/PUT /resources/:id.json
      def update
        if @resource.update(update_params)
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

        def set_resource
          @resource = Resource.find_by!(identifier: params[:id])
        end

        def create_params
          params.require(:resource).permit(:identifier, :location_uri, :width, :height, :featured_region)
        end

        def update_params
          params.require(:resource).permit(:location_uri, :width, :height, :featured_region)
        end
    end
  end
end
