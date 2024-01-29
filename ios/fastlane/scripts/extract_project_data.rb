require 'xcodeproj'
require 'json'

# This function attempts to find a .xcodeproj in the parent directory.
def find_xcode_project
  current_directory = Dir.pwd
  while current_directory != '/'
    project_file = Dir.glob("#{current_directory}/*.xcodeproj").first
    return project_file if project_file

    current_directory = File.dirname(current_directory)
  end
  nil  
end

project_path = find_xcode_project

unless project_path
  raise "Xcode project not found in the parent directory."
end

project = Xcodeproj::Project.open(project_path)

configurations = []

# Iterate through each target in the project
project.targets.each do |target|
  target.build_configurations.each do |config|
    app_plist = config.build_settings['INFOPLIST_FILE'] || nil
    configuration = {
      target: target.name,
      config: config.name,
      appPlist: app_plist,
      bundleId: config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'],
      xcodeproj: File.basename(project_path),
      workspace: nil
    }
    configurations.push(configuration)
  end
end

all_targets = []
project.objects.select { |obj| obj.isa == 'PBXNativeTarget' }.each do |target|
  all_targets << target.name
end

# For extracting schemes
schemes_dir = File.join(project_path, 'xcshareddata', 'xcschemes')
schemes = []
if Dir.exist?(schemes_dir)
  schemes = Dir[schemes_dir + "/*.xcscheme"].sort_by { |f| File.mtime(f) }.map do |scheme_file|
    File.basename(scheme_file, ".xcscheme")
  end
end

# For determining the workspace
workspace_files = Dir["../../*.xcworkspace"]
unless workspace_files.empty?
  workspace_name = File.basename(workspace_files.first, ".xcworkspace")
else
  workspace_name = nil
end

configurations.each do |config|
  config[:workspace] = workspace_name || nil
end

# Writing the result to a JSON file
File.open('../project_data.json', 'w') do |file|
  file.write(JSON.pretty_generate({    
    targets: all_targets,
    schemes: schemes,
    configurations: configurations
  }))
end

puts "Data has been written to project_data.json"
