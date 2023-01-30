module Mrsk::Cli::Helpers::ImageList
  extend self

  # Convert captured string from terminal to array of hashes
  def captured_image_list_to_hash(captured_string)
    result = []
    captured_string.split("\n").each do |line|
    result << {
      id: line.split(',').first,
      created_at: line.split(',').last
      }
    end

    result.sort_by! do |item|
      DateTime.parse(item[:created_at]).to_i
    end

    result
  end
end
