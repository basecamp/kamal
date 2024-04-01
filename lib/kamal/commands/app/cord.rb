module Kamal::Commands::App::Cord
  def cord(version:)
    pipe \
      docker(:inspect, "-f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}'", container_name(version)),
      [ :awk, "'$2 == \"#{role.cord_volume.container_path}\" {print $1}'" ]
  end

  def tie_cord(cord)
    create_empty_file(cord)
  end

  def cut_cord(cord)
    remove_directory(cord)
  end

  private
    def create_empty_file(file)
      chain \
        make_directory_for(file),
        [ :touch, file ]
    end
end
