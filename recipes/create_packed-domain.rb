os_user = node['env-122']['os_user']
os_installer_group = node['env-122']['os_installer_group']

mw_home = node['env-122']['home']
wl_home = "#{mw_home}/wlserver"
common_home = "#{mw_home}/oracle_common"
java_home = node['java']['java_home']

# Create directories
domain_home = "#{node['domain-packed']['domains_path']}/#{node['domain-packed']['name']}"

ENV['ORACLE_HOME'] = mw_home
ENV['TZ'] = node['env-122']['os_timezone']

# Getting the domain template
domain_template_jar = File.join(Chef::Config[:file_cache_path], node['domain-packed']['domain_template_file'])

remote_file domain_template_jar do
	source "#{node['domain-packed']['domain_pack_url']}"
	headers ({"AUTHORIZATION" => "Basic #{Base64.encode64("#{node['cloud']['cloud_username']}:#{node['cloud']['cloud_password']}")}"})
	action :create
end

directory node['domain-packed']['domains_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

directory node['domain-packed']['apps_path'] do
	owner os_user
	group os_installer_group
	recursive true
	action :create
end

# Unpack command
unpack_exec = "#{common_home}/common/bin/unpack.sh -template #{domain_template_jar} -domain #{domain_home} -user_name=weblogic -password=welcome1"

execute unpack_exec do
	user os_user
	group os_installer_group
	environment ({
	'HOME' => "/home/#{os_user}",
	'USER' => os_user
})
	action :run
end

# Upstart script
start_nm_script = "/etc/init/nodemanager.conf"

template start_nm_script do
	source "start-node_manager-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
end

start_admin_server_script = "/etc/init/#{node['domain-packed']['name']}-admin_server.conf"

template start_admin_server_script do
	source "start-admin_server-12c.sh.erb"
	variables({
		:os_user => os_user,
		:domain_home => domain_home
	})
end

# Node Manager Properties file
nm_props = "#{domain_home}/nodemanager/nodemanager.properties"

template nm_props do
	source "node_manager-12c.properties.erb"
	variables({
		:domain_home => domain_home,
		:java_home => java_home
	})
end

#Start Node Manager
nm_exec  = "initctl start nodemanager"
execute nm_exec do
	action :run
end

#Start Node Manager
admin_server_exec  = "initctl start #{node['domain-packed']['name']}-admin_server"
execute admin_server_exec do
	action :run
end
