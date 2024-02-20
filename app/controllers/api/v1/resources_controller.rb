module Api
  module V1
    class ResourcesController < ApiController
      before_action :authenticate_request_token
      before_action :ensure_json_request
      before_action :set_resource, only: [:show, :create_or_replace, :destroy]

      # GET /resources/:id
      # GET /resources/:id.json
      def show
        if @resource
          render json: @resource
        else
          render json: {
            errors: ["Could not find resource with identifier: #{params[:id]}"]
          }, status: :not_found
        end
      end

      # PATCH/PUT /resources/:id
      # PATCH/PUT /resources/:id.json
      def create_or_replace
        success_status = :ok

        if @resource.nil?
          @resource = Resource.create(create_params.merge(identifier: params[:id]))
          success_status = :created
        else
          @resource.update(create_params)
        end

        if @resource.errors.present?
          render json: errors(@resource.errors.full_messages), status: :bad_request
        else
          render json: { resource: @resource }, status: success_status
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
          @resource = Resource.find_by(identifier: params[:id])
        end

        def create_params
          params.require(:resource).permit(:source_uri, :featured_region, :pcdm_type, :has_view_limitation)
        end
    end
  end
end
