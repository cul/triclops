module Triclops
  module Resource
    module AsJson
      extend ActiveSupport::Concern

      # Returns a JSON Hash representation of this resource.
      # @param options [Hash] JSON options.
      # @return [Hash] JSON representation of this resource.
      def as_json(_options = {})
        [
          :identifier,
          :has_view_limitation,
          :featured_region,
          :source_uri,
          :standard_width, :standard_height,
          :limited_width, :limited_height,
          :featured_width, :featured_height,
          :created_at, :updated_at, :accessed_at
        ].map { |field_name| [field_name, self.send(field_name)] }.to_h
      end
    end
  end
end
