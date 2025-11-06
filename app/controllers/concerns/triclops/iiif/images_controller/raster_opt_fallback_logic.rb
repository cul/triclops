module Triclops
  module Iiif
    module ImagesController
      module RasterOptFallbackLogic
        extend ActiveSupport::Concern

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockNesting, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def raster_opts_for_ready_resource_with_fallback(resource, base_type, original_raster_opts, normalized_raster_opts)
          raster_opts_to_try = normalized_raster_opts.dup
          cache_hit = resource.raster_exists?(base_type, raster_opts_to_try)

          unless cache_hit
            Rails.logger.error(
              "[#{resource.identifier}] "\
              "Cache MISS: (original_raster_opts: #{original_raster_opts}) "\
              "(raster_opts_to_try: #{raster_opts_to_try.inspect})"
            )

            # -- BEGIN temporary fallback code --
            # Try a backup raster path, using the original size opt
            raster_opts_to_try = normalized_raster_opts.merge(size: original_raster_opts[:size])
            cache_hit = resource.raster_exists?(base_type, raster_opts_to_try)

            unless cache_hit
              Rails.logger.error(
                "[#{resource.identifier}] "\
                "Second try: Cache #{cache_hit ? 'HIT' : 'MISS'} for raster_opts_to_try: #{raster_opts_to_try}"
              )

              # If nothing was found at the backup raster path AND this a request for a 'full' region,
              # try converting the size to a "!long_side,long_side" size value and see if that version exists in the cache.
              if normalized_raster_opts[:region] == 'full'
                # We expect normalized_raster_opts to have a size value of the format: "width,height" in most cases,
                # but if it doesn't then we should skip the rest of this block.
                size_opt = normalized_raster_opts[:size]
                matches = /(\d+),(\d+)/.match(size_opt)
                if matches
                  width = matches[1].to_i
                  height = matches[2].to_i
                  long_side = width > height ? width : height

                  raster_opts_to_try = normalized_raster_opts.merge(size: "!#{long_side},#{long_side}")
                  cache_hit = resource.raster_exists?(base_type, raster_opts_to_try)
                  unless cache_hit
                    Rails.logger.error(
                      "[#{resource.identifier}] "\
                      "Third try: Cache #{cache_hit ? 'HIT' : 'MISS'} for raster_opts_to_try: #{raster_opts_to_try}"
                    )

                    # Unfortunately, we cannot guarantee that converting a rounded width or height value to a
                    # "!#{long_side},#{long_side}" value will always result in the long_size value in the cache,
                    # since the generation of "!#{long_side},#{long_side}" cached items was based on the original
                    # ratio and rounding errors can occur.  So we'll also fall back to checking for
                    # "!#{long_side - 1},#{long_side - 1}" and "!#{long_side + 1},#{long_side + 1}" versions.

                    raster_opts_to_try = normalized_raster_opts.merge(size: "!#{long_side - 1},#{long_side - 1}")
                    cache_hit = resource.raster_exists?(base_type, raster_opts_to_try)
                    unless cache_hit
                      Rails.logger.error(
                        "[#{resource.identifier}] "\
                        "Fourth try: Cache #{cache_hit ? 'HIT' : 'MISS'} for raster_opts_to_try: #{raster_opts_to_try}"
                      )

                      raster_opts_to_try = normalized_raster_opts.merge(size: "!#{long_side + 1},#{long_side + 1}")
                      cache_hit = resource.raster_exists?(base_type, raster_opts_to_try)
                      unless cache_hit
                        Rails.logger.error(
                          "[#{resource.identifier}] "\
                          "Fifth try: Cache #{cache_hit ? 'HIT' : 'MISS'} for raster_opts_to_try: #{raster_opts_to_try}"
                        )
                      end
                    end
                  end
                end
              end
            end
            # -- END temporary fallback code --
          end

          [raster_opts_to_try, cache_hit]
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockNesting, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      end
    end
  end
end
