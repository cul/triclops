require 'find'

namespace :triclops do
  # TODO: Update reporting tasks below so that they work with local files or S3 files
  namespace :placeholders do
    desc "Populate the cache with derivatives for placeholder images (do this for any new deployment)"
    task generate: :environment do
      KNOWN_PLACEHOLDER_IDENTIFIERS.each do |placeholder_identifier|
        resource = Resource.find_by(identifier: placeholder_identifier)
        if resource.present?
          puts "Found existing resource for #{resource.identifier}. Deleting this resource and its existing derivatives..."
          resource.destroy
        end

        puts "Generating derivatives for #{placeholder_identifier} ..."
        resource = Resource.new(
          identifier: placeholder_identifier,
          source_uri: 'file://' + Rails.root.join('app/assets/images/placeholders/', placeholder_identifier.sub('placeholder:', '') + '.png').to_s,
          pcdm_type: BestType::PcdmTypeLookup::IMAGE,
          has_view_limitation: false,
          featured_region: "0,0,#{PLACEHOLDER_SIZE},#{PLACEHOLDER_SIZE}"
        )
        resource.create_base_derivatives_now = true # This will trigger base derivative generation on save
        resource.save!
      end
    end
  end
end
