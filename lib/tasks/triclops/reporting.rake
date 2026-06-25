require 'find'

namespace :triclops do
  namespace :reporting do
    desc "Calculate the combined IIIF cache byte size for a single identifier"
    task calculate_iiif_cache_size_for_identifier: :environment do
      identifier = ENV['identifier']
      dir_path = Triclops::RasterCache.instance.cache_directory_for_identifier(identifier)
      total_size = 0
      Find.find(dir_path) do |path|
        if File.file?(path)
          total_size += File.size(path)
        end
      end
      puts "Cache directory location for #{identifier}: #{dir_path}"
      puts "Total cache directory size: #{total_size}"
    end

    desc "Calculate the combined IIIF cache byte size for a list of PIDs"
    task calculate_iiif_cache_size: :environment do
      def print_current_stats(total_size, number_of_identifiers_counted)
        puts "Total size: #{total_size} bytes"
        puts "Average size: #{total_size / number_of_identifiers_counted} bytes"
      end

      if ENV['IDENTIFIERS'].present?
        identifiers = ENV['IDENTIFIERS'].split(',')
      elsif ENV['IDENTIFIER_LIST'].present?
        identifiers = open(ENV['IDENTIFIER_LIST'],'r').map(&:strip)
      else
        puts 'Error: Please supply a value for argument IDENTIFIERS (one or more comma-separated identifiers)'
        next
      end

      puts 'Calculating...'
      total_size = 0

      identifiers.each_with_index do |identifier, i|
        puts "Counting #{i+1} of #{identifiers.length}"
        dir_path = Triclops::RasterCache.instance.cache_directory_for_identifier(identifier)
        Find.find(dir_path) do |path|
          if File.file?(path)
            total_size += File.size(path)
          end
        end

        if i > 0 && i % 100 == 0
          puts "--- [CURRENT STATS] ---"
          print_current_stats(total_size, i+1)
          puts "-----------------------"
        end
      end

      puts "\n\n--- DONE! ---"
      print_current_stats(total_size, identifiers.length)
    end
  end
end
