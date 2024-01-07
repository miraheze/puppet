import subprocess
import argparse
from typing import TypedDict


class DbClusterMap(TypedDict):
    c1: str
    c2: str
    c3: str
    c4: str
    c5: str


# Define the mapping of db clusters to db names
db_clusters: DbClusterMap = {
    'c1': 'db131',
    'c2': 'db101',
    'c3': 'db142',
    'c4': 'db121',
    'c5': 'db131',
}


def generate_salt_command(cluster: str, command: str) -> str:
    return f'salt-ssh -E "{cluster}*" cmd.run "{command}"'


def execute_salt_command(salt_command: str, shell: bool = False, stdout: int = subprocess.PIPE, text: bool = False) -> subproccess.run:
    return subprocess.run(salt_command=salt_command, shell=shell, stdout=stdout, text=text)


def get_db_cluster(oldwiki_db: str) -> str:
    command = generate_salt_command('db131*', f'cmd.run "mysql -e \'SELECT wiki_dbcluster FROM mhglobal.cw_wikis WHERE wiki_dbname = "{oldwiki_db}" \' "')
    result = execute_salt_command(salt_command=command, shell=True, stdout=subprocess.PIPE, text=True)
    cluster_name = result.stdout.strip()
    return db_clusters.get(cluster_name)


def rename_wiki(oldwiki_db: str, newwiki_db: str) -> None:
    # Step 1: Get the db cluster for the old wiki dbname
    oldwiki_cluster = get_db_cluster(oldwiki_db)

    if not oldwiki_cluster:
        print(f'Error: Unable to determine the db cluster for {oldwiki_db}')
        return

    # Step 2: Execute SQL commands for rename
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f'mysqldump {oldwiki_db} > oldwikidb.sql'))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"mysql -e 'CREATE DATABASE {newwiki_db}'"))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"mysql -e 'USE {newwiki_db}; SOURCE /home/$user/oldwikidb.sql'"))

    # Step 3: Execute MediaWiki rename script
    execute_salt_command(salt_command=generate_salt_command('mwtask141', f'sudo -u www-data php /srv/mediawiki/w/extensions/CreateWiki/maintenance/renameWiki.php --wiki=loginwiki --rename {oldwiki_db} {newwiki_db} $user'))


def main() -> None:
    parser = argparse.ArgumentParser(description='Executes the commands needed to rename wikis')
    parser.add_argument('--oldwiki', required=True, help='Old wiki database name')
    parser.add_argument('--newwiki', required=True, help='New wiki database name')

    args = parser.parse_args()
    rename_wiki(args.oldwiki, args.newwiki)


if __name__ == '__main__':
    main()
