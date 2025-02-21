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
      flags = secrets_get_flags(secrets)
      secret_names = secrets.collect { |s| s.split("/").last }

      filter_condition = secret_names.any? ? "--filter '#{secret_names.map { |name| "Name == #{name.shellescape.inspect}" }.join(" || ")}'" : ""
      items = `passbolt list resources #{filter_condition} #{flags} --json`
      raise RuntimeError, "Could not read #{secrets} from Passbolt" unless $?.success?

      items = JSON.parse(items)
      found_names = items.map { |item| item["name"] }
      missing_secrets = secret_names - found_names
      raise RuntimeError, "Could not find the following secrets in Passbolt: #{missing_secrets.join(", ")}" if missing_secrets.any?

      items.to_h { |item| [item["name"], item["password"]] }
    end

    def secrets_get_flags(secrets)
      folders = secrets
        .select { |s| s.include?("/") }
        .map { |s| s.split("/").first }
        .uniq

      if folders.any?
        folder_ids = folders.map do |folder|
          fetch_folder = `passbolt list folders --filter 'Name == \"#{folder.shellescape}\"' --json`
          raise RuntimeError, "Could not read folder #{folder} from Passbolt" unless $?.success?

          folder_items = JSON.parse(fetch_folder)
          folder_item = folder_items.find { |item| item["name"] == folder }
          folder_item["id"]
        end

        "--folder #{folder_ids.join(" --folder ")}"
      else
        ""
      end
    end

    def check_dependencies!
      raise RuntimeError, "Passbolt CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `passbolt --version 2> /dev/null`
      $?.success?
    end
end