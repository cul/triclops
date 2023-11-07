namespace :triclops do
  namespace :setup do

    desc "Set up application config files"
    task :config_files do
      config_template_dir = Rails.root.join('config', 'templates')
      config_dir = Rails.root.join('config')
      Dir.foreach(config_template_dir) do |entry|
        next unless entry.end_with?('.yml')
        src_path = File.join(config_template_dir, entry)
        dst_path = File.join(config_dir, entry.gsub('.template', ''))
        if File.exist?(dst_path)
          puts Rainbow("File already exists (skipping): #{dst_path}").blue.bright + "\n"
        else
          FileUtils.cp(src_path, dst_path)
          puts Rainbow("Created file at: #{dst_path}").green
        end
      end
    end

    desc "Set up sample records"
    task sample_resources: :environment do
      [
        {
          identifier: 'sample',
          source_uri: 'railsroot://' + File.join('spec', 'fixtures', 'files', 'sample.jpg'),
          width: 1920,
          height: 3125,
          featured_region: '320,616,1280,1280'
        },
        {
          identifier: 'sample-with-transparency',
          source_uri: 'railsroot://' + File.join('spec', 'fixtures', 'files', 'sample-with-transparency.png'),
          width: 1920,
          height: 1920,
          featured_region: '320,320,1280,1280'
        },
        {
          identifier: 'sound-resource',
          source_uri: 'placeholder://sound',
          width: 2292,
          height: 2292,
          featured_region: '0,0,1280,1280'
        }
      ].each do |resource_params|
        identifier = resource_params[:identifier]
        if Resource.find_by(identifier: identifier).nil?
          Resource.create!(resource_params)
          puts Rainbow("Resource [#{identifier}] created.").green
        else
          puts Rainbow("Resource [#{identifier}] skipped (already exists).").blue.bright
        end
      end
    end

  end
end
