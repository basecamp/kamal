class Kamal::Secrets::Adapters::GitlabCi < Kamal::Secrets::Adapters::Base
  def requires_account?
    false
  end

  private
    def login(*)
      nil
    end

    def fetch_secrets(secrets, from:, **)
      variables = glab_variable_list

      {}.tap do |results|
        variables.each do |var|
          next if secrets.any? && !secrets.include?(var["key"])

          case var["environment_scope"]
          when "*"
            results[var["key"]] ||= var["value"]
          when from
            results[var["key"]] = var["value"]
          end
        end
      end
    end

    def glab_variable_list
      per_page = 100
      all = []

      (1..).each do |page|
        output = `glab variable list --output json --per-page #{per_page} --page #{page}`
        raise RuntimeError, "Failed to list GitLab CI/CD variables" unless $?.success?

        variables = JSON.parse(output)
        all.concat(variables)

        break if variables.length < per_page
      end

      all
    end

    def check_dependencies!
      raise RuntimeError, "glab CLI is not installed" unless cli_installed?
    end

    def cli_installed?
      `glab --version 2> /dev/null`
      $?.success?
    end
end
