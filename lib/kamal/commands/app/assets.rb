module Kamal::Commands::App::Assets
  def extract_assets
    asset_container = "#{role.container_prefix}-assets"

    combine \
      make_directory(role.asset_extracted_directory),
      [ *docker(:container, :rm, asset_container, "2> /dev/null"), "|| true" ],
      docker(:container, :create, "--name", asset_container, config.absolute_image),
      docker(:container, :cp, "-L", "#{asset_container}:#{role.asset_path}/.", role.asset_extracted_directory),
      docker(:container, :rm, asset_container),
      by: "&&"
  end

  def sync_asset_volumes(other_versions: [])
    versions = Array(other_versions).compact.uniq - [ config.version ]
    new_extracted_path, new_volume_path = role.asset_extracted_directory(config.version), role.asset_volume.host_path

    commands = [ make_directory(new_volume_path), copy_contents(new_extracted_path, new_volume_path) ]

    versions.each do |version|
      commands << copy_contents(new_extracted_path, role.asset_volume(version).host_path, continue_on_error: true)
      commands << copy_contents(role.asset_extracted_directory(version), new_volume_path, continue_on_error: true)
    end

    chain *commands
  end

  def clean_up_assets(keep_versions: [])
    versions = [ config.version, *keep_versions ].compact.uniq

    chain \
      find_and_remove_other_siblings(versions.map { |version| role.asset_extracted_directory(version) }),
      find_and_remove_other_siblings(versions.map { |version| role.asset_volume_directory(version) })
  end

  private
    def find_and_remove_other_siblings(paths)
      [
        :find,
        Pathname.new(paths.first).dirname.to_s,
        "-maxdepth 1",
        "-name", "'#{role.name}-*'",
        *paths.flat_map { |path| [ "!", "-name", Pathname.new(path).basename.to_s ] },
        "-exec rm -rf \"{}\" +"
      ]
    end

    def copy_contents(source, destination, continue_on_error: false)
      [ :cp, "-rnT", "#{source}", destination, *("|| true" if continue_on_error) ]
    end
end
