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

      # GET /resources
      def index
        per_page, status, page, identifier = get_index_query_params(index_params[:per_page], index_params[:status], index_params[:page], index_params[:identifier])

        resources = Resource
        identifier && identifier != 'any' && resources = resources.where(identifier: identifier)
        status && status != 'any' && resources = resources.where(status: status)
        resources, last_page = find_page(resources, page, per_page)

        render json:
          { resources: resources.map(&:attributes), last_page: last_page }
      end

      private

        def find_page(resources, page, per_page)
          last_page = per_page * (page - 1) < resources.order(:status).length && per_page * page >= resources.order(:status).length

          resources = resources.limit(per_page).offset((page - 1) * per_page)
          status && status != 'any' && resources = resources.order(:status)
          [resources, last_page]
        end

        def get_index_query_params(per_page_p, status_p, page_p, identifier_p)
          statuses = ['pending', 'processing', 'failure', 'ready']

          per_page = per_page_p ? Integer(per_page_p) : 50
          param_status = status_p.is_a?(String) ? status_p.downcase : status_p
          identifier = identifier_p.is_a?(String) ? identifier_p.downcase : identifier_p
          status = statuses.include?(param_status) ? statuses.index(param_status) : param_status
          page = page_p ? Integer(page_p) : 1

          [per_page, status, page, identifier]
        end

        def set_resource
          @resource = Resource.find_by(identifier: params[:id])
        end

        def create_params
          params.require(:resource).permit(:source_uri, :featured_region, :pcdm_type)
        end

        def index_params
          params.permit(:status, :page, :identifier, :format, :per_page)
        end
    end
  end
end
