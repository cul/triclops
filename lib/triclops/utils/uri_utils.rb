# frozen_string_literal: true

# TODO: A very similar UriUtils file also exists in the Hyacinth 2 code base.
# Probably want to move this to a shared gem at some point.
class Triclops::Utils::UriUtils
  # Converts a file path to a location URI value
  def self.file_path_to_location_uri(path)
    raise ArgumentError, "Given path must be absolute.  Must start with a slash: #{path}" unless path.start_with?('/')

    "file://#{Addressable::URI.encode(path).gsub('&', '%26').gsub('#', '%23')}"
  end

  # Converts a file, railsroot, or placeholder URI to a file path
  def self.location_uri_to_file_path(location_uri)
    parsed_uri = Addressable::URI.parse(location_uri)
    uri_scheme = parsed_uri.scheme
    unencoded_uri_path = Addressable::URI.unencode(parsed_uri.path)

    case uri_scheme
    when 'file'
      return unencoded_uri_path
    when 'railsroot'
      return Rails.root.join(unencoded_uri_path[1..]).to_s
    when 'placeholder'
      return File.join(PLACEHOLDER_ROOT, "#{unencoded_uri_path[1..]}.png")
    end

    raise ArgumentError, "Unhandled URI: #{location_uri}"
  end
end
