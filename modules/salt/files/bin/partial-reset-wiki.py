import subprocess
import sys
import os
import argparse
from typing import Optional, TypedDict


class DbClusterMap(TypedDict):
    c1: str
    c2: str
    c3: str
    c4: str
    c5: str


# Define the mapping of db clusters to db names
db_clusters: DbClusterMap = {
    'c1': 'db151',
    'c2': 'db161',
    'c3': 'db171',
    'c4': 'db181',
}


def generate_salt_command(cluster: str, command: str) -> str:
    return f'salt-ssh -E "{cluster}" cmd.run "{command}"'


def execute_salt_command(salt_command: str, shell: bool = True, stdout: Optional[int] = None, text: Optional[bool] = None) -> Optional[subprocess.CompletedProcess]:
    response = input(f'EXECUTE (type c(continue), s(kip), a(bort): {salt_command}')
    if response in ['c', 'continue']:
        return subprocess.run(salt_command, shell=shell, stdout=stdout, text=text)
    if response in ['s', 'skip']:
        return None
    sys.exit(1)  # noqa: R503


def get_db_cluster(wiki: str) -> str:
    db_query = f'SELECT wiki_dbcluster FROM mhglobal.cw_wikis WHERE wiki_dbname = \\"{wiki}\\"'
    command = generate_salt_command('db171', f"sudo -i mysql --skip-column-names -e '{db_query}'")
    result = execute_salt_command(salt_command=command, stdout=subprocess.PIPE, text=True)
    if result:
        cluster_name = result.stdout.strip()
        cluster_data = cluster_name.split('\n')
        cluster_data_b = cluster_data[1].split(' ')
        print(cluster_data_b)
        cluster_name = cluster_data_b[4]

        return db_clusters[cluster_name]  # type: ignore[literal-required]
    raise KeyboardInterrupt('Impossible to skip. Aborted.')


def reset_wiki(wiki: str) -> None:
    # Step 1: Get the db cluster for the wiki

    try:
        wiki_cluster = get_db_cluster(wiki)
    except (KeyError, IndexError):
        print(f'Error: Unable to determine the db cluster for {wiki}')
        sys.exit(1)

    # Step 2: Execute deleteWiki.php
    execute_salt_command(salt_command=generate_salt_command('mwtask181', f'mwscript extensions/CreateWiki/deleteWiki.php loginwiki --deletewiki {wiki} --delete {os.getlogin()}'))

    # Step 3: Backup and drop database 
    execute_salt_command(salt_command=generate_salt_command(wiki_cluster, f"sudo -i mysqldump {wiki} > {wiki}.sql'"))
    execute_salt_command(salt_command=generate_salt_command(wiki_cluster, f"sudo -i mysql -e 'DROP DATABASE {wiki}'"))


def main() -> None:
    parser = argparse.ArgumentParser(description='Executes the commands needed to reset wikis')
    parser.add_argument('--wiki', required=True, help='Old wiki database name')

    args = parser.parse_args()
    reset_wiki(args.wiki)


if __name__ == '__main__':
    main()
