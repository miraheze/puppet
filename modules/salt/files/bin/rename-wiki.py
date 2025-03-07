import subprocess
import sys
import argparse
from typing import Optional, TypedDict


class DbClusterMap(TypedDict):
    c1: str
    c2: str
    c3: str
    c4: str


# Define the mapping of db clusters to db names
db_clusters: DbClusterMap = {
    'c1': 'db151',
    'c2': 'db161',
    'c3': 'db171',
    'c4': 'db181',
}


def generate_salt_command(cluster: str, command: str) -> str:
    return f'salt-ssh -E "{cluster}*" cmd.run "{command}"'


def execute_salt_command(salt_command: str, shell: bool = False, stdout: Optional[int] = None, text: Optional[bool] = None) -> Optional[subprocess.CompletedProcess]:
    response = input(f'EXECUTE (type c(continue), s(kip), a(bort): {salt_command}')
    if response in ['c', 'continue']:
        return subprocess.run(salt_command, shell=shell, stdout=stdout, text=text)
    if response in ['s', 'skip']:
        return None
    sys.exit(1)  # noqa: R503


def get_db_cluster(oldwiki_db: str) -> str:
    command = generate_salt_command('db171*', f'cmd.run "mysql -e \'SELECT wiki_dbcluster FROM mhglobal.cw_wikis WHERE wiki_dbname = "{oldwiki_db}" \' "')
    result = execute_salt_command(salt_command=command, shell=True, stdout=subprocess.PIPE, text=True)
    if result:
        cluster_name = result.stdout.strip()
        return db_clusters[cluster_name]  # type: ignore[literal-required]
    raise KeyboardInterrupt('Impossible to skip. Aborted.')


def rename_wiki(oldwiki_db: str, newwiki_db: str) -> None:
    # Step 1: Get the db cluster for the old wiki dbname
    oldwiki_cluster = get_db_cluster(oldwiki_db)

    try:
        oldwiki_cluster = get_db_cluster(oldwiki_db)
    except KeyError:
        print(f'Error: Unable to determine the db cluster for {oldwiki_db}')
        sys.exit(1)

    # Step 2: Execute SQL commands for rename
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f'mysqldump {oldwiki_db} > oldwikidb.sql'))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"mysql -e 'CREATE DATABASE {newwiki_db}'"))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"mysql -e 'USE {newwiki_db}; SOURCE /home/$user/oldwikidb.sql'"))

    # Step 3: Execute MediaWiki rename script
    execute_salt_command(salt_command=generate_salt_command('mwtask181', f'sudo -u www-data php /srv/mediawiki/1.43/maintenance/run.php CreateWiki:RenameWiki --wiki=loginwiki --rename {oldwiki_db} {newwiki_db} $user'))


def main() -> None:
    parser = argparse.ArgumentParser(description='Executes the commands needed to rename wikis')
    parser.add_argument('--oldwiki', required=True, help='Old wiki database name')
    parser.add_argument('--newwiki', required=True, help='New wiki database name')

    args = parser.parse_args()
    rename_wiki(args.oldwiki, args.newwiki)


if __name__ == '__main__':
    main()
