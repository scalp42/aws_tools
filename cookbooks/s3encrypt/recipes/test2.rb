file "#{::Chef::Config['file_cache_path']}/delete_me2" do
  content "#{hash['user2']}"
  sensitive true
end
