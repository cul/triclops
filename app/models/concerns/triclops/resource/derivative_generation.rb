module Triclops
  module Resource
    module DerivativeGeneration
      extend ActiveSupport::Concern

      def raise_exception_if_base_derivative_dependency_missing!
        missing_fields = []
        missing_fields << 'source_uri' if self.source_uri.nil?
        missing_fields << 'featured_region' if self.featured_region.nil?

        return if missing_fields.empty?

        raise Triclops::Exceptions::MissingBaseImageDependencyException,
              "Cannot generate base derivatives for #{self.identifier} because the following required fields are nil: " +
              missing_fields.join(', ')
      end

      # Generates base derivatives
      # rubocop:disable Metrics/AbcSize
      def generate_base_derivatives_if_not_exist!
        raise_exception_if_base_derivative_dependency_missing!
        standard_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier, mkdir_p: true)
        limited_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier, mkdir_p: true)
        featured_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier, mkdir_p: true)

        return if File.exist?(standard_base_path) && File.exist?(limited_base_path) && File.exist?(featured_base_path)

        self.with_source_image_file do |source_image_file|
          # Use the original image to generate standard base
          unless File.exist?(standard_base_path)
            Triclops::Raster.generate(
              source_image_file.path,
              standard_base_path,
              {
                region: 'full',
                size: 'full',
                rotation: 0,
                quality: Triclops::Iiif::Constants::BASE_QUALITY,
                format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
              }
            )
          end
          # Store standard base dimensions
          # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
          Imogen.with_image(standard_base_path, { revalidate: true }) do |img|
            self.standard_width = img.width
            self.standard_height = img.height
          end

          # Use the original image to generate the limited base
          # Note: Technically the 'limited' base can be larger than the source image, if the source image
          # has a long side that's smaller than LIMITED_BASE_SIZE.  But that case will be rare, and
          # shouldn't cause any issues.
          unless File.exist?(limited_base_path)
            Triclops::Raster.generate(
              source_image_file.path,
              limited_base_path,
              {
                region: 'full',
                size: "!#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE},#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE}",
                rotation: 0,
                quality: Triclops::Iiif::Constants::BASE_QUALITY,
                format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
              }
            )
          end
          # Store limited base dimensions
          # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
          Imogen.with_image(limited_base_path, { revalidate: true }) do |img|
            self.limited_width = img.width
            self.limited_height = img.height
          end

          # Use the original image to generate the featured base
          # Note: Technically the 'featured' base can be larger than the standard base, if the standard base
          # has a long side that's smaller than FEATURED_BASE_SIZE.  But that case will be rare, and
          # shouldn't cause any issues.

          unless File.exist?(featured_base_path)
            Triclops::Raster.generate(
              source_image_file.path,
              featured_base_path,
              {
                region: self.featured_region,
                size: "!#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE},#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE}",
                rotation: 0,
                quality: Triclops::Iiif::Constants::BASE_QUALITY,
                format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
              }
            )
          end

          # Store featured base dimensions
          # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
          Imogen.with_image(featured_base_path, { revalidate: true }) do |img|
            self.featured_width = img.width
            self.featured_height = img.height
          end
        end

        # Save so that width/height, limited_width/limited_height, featured_width/featured_height properties are persisted.
        self.save!

        true
      end
      # rubocop:enable Metrics/AbcSize

      # Generates commonly requested standard, reduced, and featured derivatives.
      def generate_commonly_requested_derivatives
        generate_base_derivatives_if_not_exist!

        self.generate_commonly_requested_standard_derivatives
        self.generate_commonly_requested_limited_derivatives
        self.generate_commonly_requested_featured_derivatives
      end

      # Generates the following "standard" derivatives:
      # - Scaled versions at Triclops::Iiif::Constants::RECOMMENDED_SIZES.
      # - IIIF zooming image viewer tiles
      def generate_commonly_requested_standard_derivatives
        standard_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier)

        # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_SIZES.
        Triclops::Iiif::Constants::RECOMMENDED_SIZES.each do |size|
          raster_opts = {
            region: 'full',
            size: "!#{size},#{size}",
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::DEFAULT_FORMAT
          }
          raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
            Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
            self.identifier,
            raster_opts,
            mkdir_p: true
          )
          next if File.exist?(raster_path)

          Triclops::Raster.generate(
            standard_base_path,
            raster_path,
            raster_opts
          )
        end

        # Generate IIIF zooming image viewer tiles
        Imogen.with_image(standard_base_path, { revalidate: true }) do |image|
          Imogen::Iiif::Tiles.for(
            image,
            Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(
              Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
              self.identifier
            ),
            :jpg,
            Triclops::Iiif::Constants::TILE_SIZE,
            'color'
          ) do |img, suggested_tile_dest_path, format, iiif_opts|
            FileUtils.mkdir_p(File.dirname(suggested_tile_dest_path))
            Imogen::Iiif.convert(img, suggested_tile_dest_path, format, iiif_opts)
          end
        end
        # If the Imogen::Iiif::Tiles.generate_with_vips_dzsave method were fully implemented,
        # we would call it like this:
        # Imogen.with_image(standard_base_path, { revalidate: true }) do |image|
        #   Imogen::Iiif::Tiles.generate_with_vips_dzsave(
        #     image,
        #     Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(self.identifier),
        #     format: :jpg,
        #     tile_size: Triclops::Iiif::Constants::TILE_SIZE,
        #     tile_filename_without_extension: 'color'
        #   )
        # end

        true
      end

      # Generates the following "limited" derivatives:
      # - Scaled versions at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
      # - IIIF zooming image viewer tiles
      def generate_commonly_requested_limited_derivatives
        limited_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier)

        # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
        Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.each do |size|
          raster_opts = {
            region: 'full',
            size: "!#{size},#{size}",
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::DEFAULT_FORMAT
          }
          raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
            Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
            self.identifier,
            raster_opts,
            mkdir_p: true
          )
          next if File.exist?(raster_path)

          Triclops::Raster.generate(
            limited_base_path,
            raster_path,
            raster_opts
          )
        end

        # Generate IIIF zooming image viewer tiles
        Imogen.with_image(limited_base_path, { revalidate: true }) do |image|
          Imogen::Iiif::Tiles.for(
            image,
            Triclops::RasterCache.instance.iiif_cache_directory_for_identifier(
              Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
              self.identifier
            ),
            :jpg,
            Triclops::Iiif::Constants::TILE_SIZE,
            'color'
          ) do |img, suggested_tile_dest_path, format, iiif_opts|
            FileUtils.mkdir_p(File.dirname(suggested_tile_dest_path))
            Imogen::Iiif.convert(img, suggested_tile_dest_path, format, iiif_opts)
          end
        end
      end

      # Generates the following "featured" derivatives:
      # - Scaled versions, at Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.
      def generate_commonly_requested_featured_derivatives
        featured_base_path = Triclops::RasterCache.instance.base_cache_path(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier)

        # Generate recommended featured versions at PRE_GENERATED_SQUARE_SIZES
        Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.each do |size|
          raster_opts = {
            region: 'full',
            size: "!#{size},#{size}",
            rotation: 0,
            quality: Triclops::Iiif::Constants::BASE_QUALITY,
            format: Triclops::Iiif::Constants::DEFAULT_FORMAT
          }
          raster_path = Triclops::RasterCache.instance.iiif_cache_path_for_raster(
            Triclops::Iiif::Constants::BASE_TYPE_FEATURED,
            self.identifier,
            raster_opts,
            mkdir_p: true
          )
          next if File.exist?(raster_path)

          Triclops::Raster.generate(
            featured_base_path,
            raster_path,
            raster_opts
          )
        end

        true
      end
    end
  end
end
