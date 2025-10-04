class Kamal::Secrets::Adapters::Passbolt < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private

    def login(*)
      `passbolt verify`
      raise RuntimeError, "Failed to login to Passbolt" unless $?.success?
    end

    def fetch_secrets(secrets, from:, **)
      secrets = prefixed_secrets(secrets, from: from)
      raise ArgumentError, "No secrets given to fetch" if secrets.empty?

      secret_names = secrets.collect { |s| s.split("/").last }
      folders = secrets_get_folders(secrets)

      # build filter conditions for each secret with its corresponding folder
      filter_conditions = []
      secrets.each do |secret|
        parts = secret.split("/")
        secret_name = parts.last

        if parts.size > 1
          # get the folder path without the secret name
          folder_path = parts[0..-2]

          # find the most nested folder for this path
          current_folder = nil
          current_path = []

          folder_path.each do |folder_name|
            current_path << folder_name
            matching_folders = folders.select { |f| get_folder_path(f, folders) == current_path.join("/") }
            current_folder = matching_folders.first if matching_folders.any?
          end

          if current_folder
            filter_conditions << "(Name == #{secret_name.shellescape.inspect} && FolderParentID == #{current_folder["id"].shellescape.inspect})"
          end
        else
          # for root level secrets (no folders)
          filter_conditions << "Name == #{secret_name.shellescape.inspect}"
        end
      end

      filter_condition = filter_conditions.any? ? "--filter '#{filter_conditions.join(" || ")}'" : ""
      items = `passbolt list resources #{filter_condition} #{folders.map { |item| "--folder #{item["id"]}" }.join(" ")} --json`
      raise RuntimeError, "Could not read #{secrets} from Passbolt" unless $?.success?

      items = JSON.parse(items)
      found_names = items.map { |item| item["name"] }
      missing_secrets = secret_names - found_names
      raise RuntimeError, "Could not find the following secrets in Passbolt: #{missing_secrets.join(", ")}" if missing_secrets.any?

      items.to_h { |item| [ item["name"], item["password"] ] }
    end

    def secrets_get_folders(secrets)
      # extract all folder paths (both parent and nested)
      folder_paths = secrets
        .select { |s| s.include?("/") }
        .map { |s| s.split("/")[0..-2] } # get all parts except the secret name
        .uniq

      return [] if folder_paths.empty?

      all_folders = []

      # first get all top-level folders
      parent_folders = folder_paths.map(&:first).uniq
      filter_condition = "--filter '#{parent_folders.map { |name| "Name == #{name.shellescape.inspect}" }.join(" || ")}'"
      fetch_folders = `passbolt list folders #{filter_condition} --json`
      raise RuntimeError, "Could not read folders from Passbolt" unless $?.success?

      parent_folder_items = JSON.parse(fetch_folders)
      all_folders.concat(parent_folder_items)

      # get nested folders for each parent
      folder_paths.each do |path|
        next if path.size <= 1 # skip non-nested folders

        parent = path[0]
        parent_folder = parent_folder_items.find { |f| f["name"] == parent }
        next unless parent_folder

        # for each nested level, get the folders using the parent's ID
        current_parent = parent_folder
        path[1..-1].each do |folder_name|
          filter_condition = "--filter 'Name == #{folder_name.shellescape.inspect} && FolderParentID == #{current_parent["id"].shellescape.inspect}'"
          fetch_nested = `passbolt list folders #{filter_condition} --json`
          next unless $?.success?

          nested_folders = JSON.parse(fetch_nested)
          break if nested_folders.empty?

          all_folders.concat(nested_folders)
          current_parent = nested_folders.first
        end
      end

      # check if we found all required folders
      found_paths = all_folders.map { |f| get_folder_path(f, all_folders) }
      missing_paths = folder_paths.map { |path| path.join("/") } - found_paths
      raise RuntimeError, "Could not find the following folders in Passbolt: #{missing_paths.join(", ")}" if missing_paths.any?

      all_folders
    end

    def get_folder_path(folder, all_folders, path = [])
      path.unshift(folder["name"])
      return path.join("/") if folder["folder_parent_id"].to_s.empty?

      parent = all_folders.find { |f| f["id"] == folder["folder_parent_id"] }
      return path.join("/") unless parent

      get_folder_path(parent, all_folders, path)
    end

    def check_dependencies!
      raise RuntimeError, "Passbolt CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `passbolt --version 2> /dev/null`
      $?.success?
    end
end
