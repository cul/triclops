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

      def base_exists?(base_path)
        base_path && File.exist?(base_path)
      end

      # Generates base derivatives
      # rubocop:disable Metrics/AbcSize
      def generate_base_derivatives_if_not_exist!
        raise_exception_if_base_derivative_dependency_missing!
        source_storage_object_for_reading = Triclops::Storage.storage_object_for(self.source_uri)
        # standard_base_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier)
        limited_base_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier)
        featured_base_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier)

        return if source_storage_object_for_reading.exist? && limited_base_storage_object_for_reading.exist? && featured_base_storage_object_for_reading.exist?

        source_storage_object_for_reading.with_file do |source_image_file|
          # First, extract and store standard base dimensions from source file
          # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
          Imogen.with_image(source_image_file.path, { revalidate: true }) do |img|
            self.standard_width = img.width
            self.standard_height = img.height
          end

          # NOTE: For now, we are always skipping generation of a standard base image because the source image is
          # assumed to be readable in 100% of cases and can be used in place of a standard base image.
          # This lets us avoid essentially copying a source images to the standard base location.
          # This is why the code below is commented out.
          #
          # unless source_storage_object_for_reading.exist?
          #   # Generate a standard base image that will be used for the generation of future cached images.
          #   raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
          #     region: 'full',
          #     size: 'full',
          #     rotation: 0,
          #     quality: Triclops::Iiif::Constants::BASE_QUALITY,
          #     format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
          #   })
          #   standard_base_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_STANDARD, self.identifier)
          #   standard_base_storage_object_for_writing.write do |file|
          #     Triclops::Raster.generate(
          #       source_image_file.path,
          #       file.path,
          #       raster_opts
          #     )
          #   end
          # end

          # Use the source image to generate the limited base.
          # Note: Technically the 'limited' base can be larger than the source image, if the source image
          # has a long side that's smaller than LIMITED_BASE_SIZE.  But that case will be rare, and
          # shouldn't cause any issues.  It's not a big deal if we upscale a small source image.
          unless limited_base_storage_object_for_reading.exist?
            raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
              region: 'full',
              size: "!#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE},#{Triclops::Iiif::Constants::LIMITED_BASE_SIZE}",
              rotation: 0,
              quality: Triclops::Iiif::Constants::BASE_QUALITY,
              format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
            })
            limited_base_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier)
            limited_base_storage_object_for_writing.write do |file|
              Triclops::Raster.generate(
                source_image_file.path,
                file.path,
                raster_opts
              )
              # Store limited base dimensions, reading them directly from the file we just wrote.
              # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
              Imogen.with_image(file.path, { revalidate: true }) do |img|
                self.limited_width = img.width
                self.limited_height = img.height
              end
            end
          end

          # Use the original image to generate the featured base.
          # Note: Technically the 'featured' base can be larger than the standard base, if the standard base
          # has a long side that's smaller than FEATURED_BASE_SIZE.  But that case will be rare, and
          # shouldn't cause any issues.  It's not a big deal if we upscale a small source image.
          unless featured_base_storage_object_for_reading.exist?
            raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
              region: self.featured_region,
              size: "!#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE},#{Triclops::Iiif::Constants::FEATURED_BASE_SIZE}",
              rotation: 0,
              quality: Triclops::Iiif::Constants::BASE_QUALITY,
              format: Triclops::Iiif::Constants::BASE_IMAGE_FORMAT
            })
            featured_base_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier)
            featured_base_storage_object_for_writing.write do |file|
              Triclops::Raster.generate(
                source_image_file.path,
                file.path,
                raster_opts
              )
              # Store featured base dimensions, reading them directly from the file we just wrote.
              # NOTE: Must use `revalidate: true` option below to avoid relying on underlying vips recent operation cache.
              Imogen.with_image(file.path, { revalidate: true }) do |img|
                self.featured_width = img.width
                self.featured_height = img.height
              end
            end
          end
        end

        # Save this ActiveRecord resource so that width/height, limited_width/limited_height, and
        # featured_width/featured_height properties are persisted to the database.
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
      def generate_commonly_requested_standard_derivatives # rubocop:disable Metrics/AbcSize
        # For now, we are always using the source image to generated standard derivatives instead of a standard base
        # image.  This is because we are intentionally not generating and saving a standard base image right now.
        # That allows us to avoid essentially creating a copy of the source image at the standard base path,
        # which reduced our storage footprint.
        source_storage_object_for_reading = Triclops::Storage.storage_object_for(self.source_uri)

        source_storage_object_for_reading.with_file do |source_image_file|
          # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_SIZES.
          Triclops::Iiif::Constants::RECOMMENDED_SIZES.each do |size|
            raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
              region: 'full',
              size: "!#{size},#{size}",
              rotation: 0,
              quality: Triclops::Iiif::Constants::BASE_QUALITY,
              format: Triclops::Iiif::Constants::DEFAULT_FORMAT
            })
            raster_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
              self.identifier,
              raster_opts
            )
            next if raster_storage_object_for_reading.exist?

            raster_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
              self.identifier,
              raster_opts
            )
            raster_storage_object_for_writing.write do |file|
              Triclops::Raster.generate(
                source_image_file.path,
                file.path,
                raster_opts
              )
            end
          end

          # Generate IIIF zooming image viewer tiles
          # TODO: Look into possibly using Aws::S3::TransferManager#upload_directory for uploading all of the IIIF
          # zooming image tiles when writing to S3. It might be more efficient.
          Imogen.with_image(source_image_file.path, { revalidate: true }) do |image|
            Imogen::Iiif::Tiles.for(
              image,
              Triclops::RasterCache.instance_for_writing.iiif_cache_location_for_identifier_directory(
                Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
                self.identifier
              ),
              :jpg,
              Triclops::Iiif::Constants::TILE_SIZE,
              'color'
            ) do |img, _suggested_tile_dest_path, format, iiif_opts|
              # iiif_opts keys are :region, :size, :rotation, :quality

              raster_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
                Triclops::Iiif::Constants::BASE_TYPE_STANDARD,
                self.identifier,
                iiif_opts.merge(format: format) # Create expected raster_opts format from iiif_opts and format
              )

              raster_storage_object_for_writing.write do |file|
                Imogen::Iiif.convert(img, file.path, format, iiif_opts)
              end
            end
          rescue StandardError => e
            # If we run into an exception here, log additional information and re-raise the exception
            Rails.logger.error "Encountered a problem while generating #{Triclops::Iiif::Constants::TILE_SIZE} size tiles for #{source_image_file.path}"
            raise e
          end
        end

        true
      end

      # Generates the following "limited" derivatives:
      # - Scaled versions at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
      # - IIIF zooming image viewer tiles
      def generate_commonly_requested_limited_derivatives
        limited_base_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_LIMITED, self.identifier)

        limited_base_storage_object_for_reading.with_file do |limited_base_image_file|
          # Generate scaled rasters at Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.
          Triclops::Iiif::Constants::RECOMMENDED_LIMITED_SIZES.each do |size|
            raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
              region: 'full',
              size: "!#{size},#{size}",
              rotation: 0,
              quality: Triclops::Iiif::Constants::BASE_QUALITY,
              format: Triclops::Iiif::Constants::DEFAULT_FORMAT
            })
            raster_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
              self.identifier,
              raster_opts
            )
            next if raster_storage_object_for_reading.exist?

            raster_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
              self.identifier,
              raster_opts
            )
            raster_storage_object_for_writing.write do |file|
              Triclops::Raster.generate(
                limited_base_image_file.path,
                file.path,
                raster_opts
              )
            end
          end

          # Generate IIIF zooming image viewer tiles
          # TODO: Look into possibly using Aws::S3::TransferManager#upload_directory for uploading all of the IIIF
          # zooming image tiles when writing to S3. It might be more efficient.
          Imogen.with_image(limited_base_image_file.path, { revalidate: true }) do |image|
            Imogen::Iiif::Tiles.for(
              image,
              Triclops::RasterCache.instance_for_writing.iiif_cache_location_for_identifier_directory(
                Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
                self.identifier
              ),
              :jpg,
              Triclops::Iiif::Constants::TILE_SIZE,
              'color'
            ) do |img, _suggested_tile_dest_path, format, iiif_opts|
              # Imogen::Iiif.convert(img, suggested_tile_dest_path, format, iiif_opts)
              raster_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
                Triclops::Iiif::Constants::BASE_TYPE_LIMITED,
                self.identifier,
                iiif_opts.merge(format: format) # Create expected raster_opts format from iiif_opts and format
              )

              raster_storage_object_for_writing.write do |file|
                Imogen::Iiif.convert(img, file.path, format, iiif_opts)
              end
            end
          end
        end
      end

      # Generates the following "featured" derivatives:
      # - Scaled versions, at Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.
      def generate_commonly_requested_featured_derivatives
        featured_base_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_base(Triclops::Iiif::Constants::BASE_TYPE_FEATURED, self.identifier)

        featured_base_storage_object_for_reading.with_file do |featured_base_image_file|
          # Generate recommended featured versions at PRE_GENERATED_SQUARE_SIZES
          Triclops::Iiif::Constants::PRE_GENERATED_SQUARE_SIZES.each do |size|
            raster_opts = Triclops::Iiif::RasterOptNormalizer.normalize_raster_opts(self, {
              region: 'full',
              size: "!#{size},#{size}",
              rotation: 0,
              quality: Triclops::Iiif::Constants::BASE_QUALITY,
              format: Triclops::Iiif::Constants::DEFAULT_FORMAT
            })
            raster_storage_object_for_reading = Triclops::RasterCache.instance_for_reading.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_FEATURED,
              self.identifier,
              raster_opts
            )
            next if raster_storage_object_for_reading.exist?

            raster_storage_object_for_writing = Triclops::RasterCache.instance_for_writing.storage_object_for_raster(
              Triclops::Iiif::Constants::BASE_TYPE_FEATURED,
              self.identifier,
              raster_opts
            )
            raster_storage_object_for_writing.write do |file|
              Triclops::Raster.generate(
                featured_base_image_file.path,
                file.path,
                raster_opts
              )
            end
          end
        end

        true
      end
    end
  end
end
