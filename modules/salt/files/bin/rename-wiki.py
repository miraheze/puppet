import subprocess
import sys
import os
import argparse
import re
import json
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

TASK_SERVER = 'mwtask181'


def generate_salt_command(cluster: str, command: str) -> str:
    return f'salt-ssh -E "{cluster}*" cmd.run "{command}"'


def execute_salt_command(salt_command: str, shell: bool = True, stdout: Optional[int] = None, text: Optional[bool] = None) -> Optional[subprocess.CompletedProcess]:
    response = input(f'EXECUTE (type c(continue), s(kip), a(bort): {salt_command}')
    if response in ['c', 'continue']:
        return subprocess.run(salt_command, shell=shell, stdout=stdout, text=text)
    if response in ['s', 'skip']:
        return None
    sys.exit(1)  # noqa: R503


def get_db_cluster(oldwiki_db: str) -> str:
    db_query = f'SELECT wiki_dbcluster FROM mhglobal.cw_wikis WHERE wiki_dbname = \\"{oldwiki_db}\\"'
    command = generate_salt_command('db171', f"sudo -i mysql --skip-column-names -e '{db_query}'")
    result = execute_salt_command(salt_command=command, stdout=subprocess.PIPE, text=True)
    if result:
         cluster_name = result.stdout.strip()
         #print(cluster_name)
         cluster_data = cluster_name.split('\n')
         cluster_data_b = cluster_data[1].split(' ')
         print(cluster_data_b)
         #print("Extracted cluster_name:", cluster_name)  # Print cluster_name for debugging
         cluster_name = cluster_data_b[4]

         return db_clusters[cluster_name]  # type: ignore[literal-required]
    raise KeyboardInterrupt('Impossible to skip. Aborted.')


def rename_wiki(oldwiki_db: str, newwiki_db: str) -> None:
    # Step 1: Get the db cluster for the old wiki dbname

    try:
        oldwiki_cluster = get_db_cluster(oldwiki_db)
    except KeyError, IndexError:
        print(f'Error: Unable to determine the db cluster for {oldwiki_db}')
        sys.exit(1)

    # Step 2: Execute SQL commands for rename
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f'sudo -i mysqldump {oldwiki_db} > /home/{os.getlogin()}/{oldwiki_db}.sql'))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"sudo -i mysql -e 'CREATE DATABASE {newwiki_db}'"))
    execute_salt_command(salt_command=generate_salt_command(oldwiki_cluster, f"sudo -i mysql -e 'USE {newwiki_db}; SOURCE /home/{os.getlogin()}/{oldwiki_db}.sql;'"))

    # Step 3: Execute MediaWiki rename script
    execute_salt_command(salt_command=generate_salt_command(TASK_SERVER, f'mwscript extensions/CreateWiki/renameWiki.php loginwiki --no-log --rename {oldwiki_db} {newwiki_db} {os.getlogin()}'))
    execute_salt_command(salt_command=generate_salt_command(TASK_SERVER, f"/usr/local/bin/logsalmsg '{os.getlogin()} renamed {oldwiki_db} to {newwiki_db} using renamewiki.py'"))


def main() -> None:
    parser = argparse.ArgumentParser(description='Executes the commands needed to rename wikis')
    parser.add_argument('--oldwiki', required=True, help='Old wiki database name')
    parser.add_argument('--newwiki', required=True, help='New wiki database name')

    args = parser.parse_args()
    rename_wiki(args.oldwiki, args.newwiki)


if __name__ == '__main__':
    main()
