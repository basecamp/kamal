module Kamal::Commands::App::Assets
  def extract_assets
    asset_container = "#{role.container_prefix}-assets"

    combine \
      make_directory(role.asset_extracted_path),
      [ *docker(:stop, "-t 1", asset_container, "2> /dev/null"), "|| true" ],
      docker(:run, "--name", asset_container, "--detach", "--rm", config.absolute_image, "sleep 1000000"),
      docker(:cp, "-L", "#{asset_container}:#{role.asset_path}/.", role.asset_extracted_path),
      docker(:stop, "-t 1", asset_container),
      by: "&&"
  end

  def sync_asset_volumes(old_version: nil)
    new_extracted_path, new_volume_path = role.asset_extracted_path(config.version), role.asset_volume.host_path
    if old_version.present?
      old_extracted_path, old_volume_path = role.asset_extracted_path(old_version), role.asset_volume(old_version).host_path
    end

    commands = [ make_directory(new_volume_path), copy_contents(new_extracted_path, new_volume_path) ]

    if old_version.present?
      commands << copy_contents(new_extracted_path, old_volume_path, continue_on_error: true)
      commands << copy_contents(old_extracted_path, new_volume_path, continue_on_error: true)
    end

    chain *commands
  end

  def clean_up_assets
    chain \
      find_and_remove_older_siblings(role.asset_extracted_path),
      find_and_remove_older_siblings(role.asset_volume_path)
  end

  private
    def find_and_remove_older_siblings(path)
      [
        :find,
        Pathname.new(path).dirname.to_s,
        "-maxdepth 1",
        "-name", "'#{role.container_prefix}-*'",
        "!", "-name", Pathname.new(path).basename.to_s,
        "-exec rm -rf \"{}\" +"
      ]
    end

    def copy_contents(source, destination, continue_on_error: false)
      [ :cp, "-rnT", "#{source}", destination, *("|| true" if continue_on_error) ]
    end
end
