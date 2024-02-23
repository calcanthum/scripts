import subprocess
import json
import argparse

service_name_mapping = {
    'mysql-server': 'mysql.service',
    'samba': 'smbd.service',
    'nfs-kernel-server': 'nfs-server.service',
    'bind9': 'named.service',
    'openvpn': 'openvpn@.service', 
    'memcached': 'memcached.service',
    'redis': 'redis-server.service',
    'bacula': 'bacula-director.service',
    'rabbitmq': 'rabbitmq-server.service',
    'elasticsearch': 'elasticsearch.service',
    'solr': 'solr.service',
    'activemq': 'activemq.service',
    'mattermost-server': 'mattermost.service',
    'zulip-server': 'zulip-server.service',
    'influxdb': 'influxdb.service',
}

def get_installed_packages():
    try:
        output = subprocess.check_output(['dpkg', '--list'], universal_newlines=True)
        return output
    except subprocess.CalledProcessError as e:
        print(f"Failed to get package list: {e}")
    except OSError as e:
        print(f"Command execution failed: {e}")
    return None

def get_service_status():
    try:
        output = subprocess.check_output(['systemctl', 'list-units', '--type=service', '--all'], universal_newlines=True)
        return output
    except subprocess.CalledProcessError as e:
        print(f"Failed to get service status: {e}")
    except OSError as e:
        print(f"Command execution failed: {e}")
    return None

def parse_service_status(service_status):
    if service_status is None:
        return []
    services = []
    lines = service_status.split("\n")
    for line in lines:
        parts = line.split()
        if len(parts) > 2 and parts[0].endswith('.service'):
            service_name = parts[0]
            active_state = parts[2]
            sub_state = parts[3] if len(parts) > 3 else ""
            services.append((service_name, active_state, sub_state))
    return services

def parse_package_list(package_list):
    if package_list is None:
        return []
    packages = []
    lines = package_list.split("\n")
    for line in lines:
        if line.startswith("ii"):
            parts = line.split()
            try:
                package_name = parts[1]
                version = parts[2]
                packages.append((package_name, version))
            except IndexError:
                continue
    return packages

def guess_server_role(packages_with_versions, active_services):
    server_roles = {
        'webserver': ['wordpress', 'nginx', 'apache2'],
        'database_server': ['mysql-server', 'postgresql', 'mariadb'],
        'mail_server': ['dovecot'],
        'file_server': ['samba', 'nfs-kernel-server'],
        'dns_server': ['bind9', 'dnsmasq'],
        'vpn_server': ['openvpn', 'strongswan'],
        'monitoring_server': ['nagios', 'prometheus', 'grafana', 'zabbix-server'],
        'containerization': ['docker.io', 'containerd', 'kubelet'],
        'load_balancer': ['haproxy', 'nginx'],
        'caching_server': ['memcached', 'redis'],
        'ci_cd_server': ['jenkins', 'gitlab-runner'],
        'configuration_management': ['ansible', 'puppet', 'chef'],
        'security_server': ['fail2ban', 'snort', 'openvas'],
        'backup_server': ['duplicity', 'bacula', 'amanda'],
        'messaging_server': ['rabbitmq', 'kafka'],
        'search_server': ['elasticsearch', 'solr'],
        'streaming_server': ['icecast2', 'nginx-rtmp'],
        'queuing_server': ['rabbitmq-server', 'activemq'],
        'collaboration_server': ['mattermost-server', 'zulip-server'],
        'time_series_db_server': ['influxdb', 'timescaledb'],
        'graph_db_server': ['neo4j', 'orientdb'],
    }

    installed_roles = {}
    for role, role_packages in server_roles.items():
        for pkg, version in packages_with_versions:
            if pkg in role_packages:
                role_info = installed_roles.get(role, {'packages': [], 'services': {}})
                role_info['packages'].append({'name': pkg, 'version': version})
                installed_roles[role] = role_info
                
                # Modified logic to handle custom service name mappings
                service_name = service_name_mapping.get(pkg, f"{pkg}.service")
                for service_info in active_services:
                    if service_info[0].startswith(service_name.replace('.service', '')):
                        service_state = determine_service_state(service_info[1], service_info[2])
                        if service_state not in role_info['services']:
                            role_info['services'][service_state] = []
                        role_info['services'][service_state].append({'name': service_info[0], 'status': f"{service_info[1]} ({service_info[2]})"})
                        installed_roles[role] = role_info

    return installed_roles

def determine_service_state(active_state, sub_state):
    if active_state == 'active' and sub_state == 'running':
        return 'Running'
    elif active_state == 'inactive' or sub_state == 'dead':
        return 'Capable'
    else:
        return 'Error'

def main(output_format):
    package_list = get_installed_packages()
    service_status = get_service_status()
    if package_list is None or service_status is None:
        print("Failed to retrieve data. Exiting.")
        return
    packages_with_versions = parse_package_list(package_list)
    active_services = parse_service_status(service_status)
    roles_with_packages = guess_server_role(packages_with_versions, active_services)
    
    if output_format == 'json':
        print(json.dumps(roles_with_packages, indent=4))
    elif output_format == 'human':
        for role, details in roles_with_packages.items():
            print(f"Role: {role}")
            if details['packages']:
                print("  Packages:")
                for pkg in details['packages']:
                    print(f"    - {pkg['name']} (Version: {pkg['version']})")
            if details['services']:
                for state, services in details['services'].items():
                    print(f"  Services ({state}):")
                    for service in services:
                        print(f"    - {service['name']} Status: {service['status']}")
            print("\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Get installed packages and service status with specified output format.')
    parser.add_argument('--output-format', choices=['json', 'human'], default='human',
                        help='Specify the output format: json or human')
    args = parser.parse_args()

    main(args.output_format)
