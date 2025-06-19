import os
import requests
from git import Repo
from datetime import datetime
import mwparserfromhell
import re

MEDIAWIKI_API_URL = 'https://meta.miraheze.org/w/api.php'
GITHUB_REPO_URL = 'git@github.com:miraheze/statichelp.git'
LOCAL_REPO_PATH = '/srv/statichelp'
SUB_DIRECTORY = 'content/tech-docs'
NAMESPACE = 1600  # Tech namespace ID
USER_AGENT = 'TechNamespaceBot/1.0 (https://github.com/miraheze/statichelp/tree/main/content/tech-docs)'

SSH_PRIVATE_KEY_PATH = '/var/lib/nagios/id_ed25519'
HTTP_PROXY = 'bastion.fsslc.wtnet:8080'

GIT_USER_EMAIL = 'noreply@wikitide.org'
GIT_USER_NAME = 'WikiTideBot'

EXCLUDED_CATEGORIES = {
    'Category:Decommissioned servers',
    'Category:Deprecated',
    'Category:Incidents',
}


def fetch_tech_pages():
    """Fetch pages in the Tech namespace."""
    session = requests.Session()
    headers = {
        'User-Agent': USER_AGENT,
    }
    params = {
        'action': 'query',
        'format': 'json',
        'generator': 'allpages',
        'gapnamespace': NAMESPACE,
        'gapfilterredir': 'nonredirects',
        'gaplimit': 'max',
        'prop': 'categories',
        'clcategories': '|'.join(category.replace(' ', '_') for category in EXCLUDED_CATEGORIES),
        'cllimit': 'max',
    }
    pages = []
    response = session.get(url=MEDIAWIKI_API_URL, params=params, headers=headers)
    response.raise_for_status()
    data = response.json()
    pages_gen = data.get('query', {}).get('pages', {})
    for _, page_data in pages_gen.items():
        categories = [cat['title'] for cat in page_data.get('categories', [])]
        if not EXCLUDED_CATEGORIES.intersection(categories):
            pages.append({'title': page_data['title']})

    return pages


def fetch_page_content(title):
    session = requests.Session()
    headers = {
        'User-Agent': USER_AGENT,
    }
    params = {
        'action': 'parse',
        'format': 'json',
        'page': title,
        'prop': 'wikitext',
    }
    response = session.get(url=MEDIAWIKI_API_URL, params=params, headers=headers)
    response.raise_for_status()
    return response.json()['parse']['wikitext']['*']


footnote_counter = 0
content_to_footnote_map = {}
name_to_footnote_map = {}

footnotes: dict[str, str] = {}


def generate_footnotes():
    """Generate the Markdown footnotes section at the end of the page."""
    if not footnotes:
        # If we have no footnotes, we can return early
        return ''

    footnotes_md = '\n\n'
    footnote_count = len(footnotes)

    for index, (key, value) in enumerate(footnotes.items()):
        footnotes_md += f'[^{key}]: {value}'

        # Only add a newline if it's not the last item
        if index < footnote_count - 1:
            footnotes_md += '\n'

    return footnotes_md


def reset_footnotes():
    """Reset footnote counter and footnote-related data."""
    global footnote_counter, footnotes, content_to_footnote_map, name_to_footnote_map
    footnote_counter = 0
    footnotes = {}
    content_to_footnote_map = {}
    name_to_footnote_map = {}


def convert_wikitext_to_markdown(wikitext):
    """
    Convert wikitext to markdown using mwparserfromhell with custom handling.
    Preserves original newlines and handles lists, tables, and indentation.
    """

    # We do this before any processing otherwise it breaks parsing
    wikitext = re.sub(r'</?(tvar|noinclude|includeonly).*?>', '', wikitext)

    def process_html_tags(node):
        """Convert specific HTML tags to Markdown."""
        global footnote_counter
        global footnotes
        global content_to_footnote_map
        global name_to_footnote_map

        tag_name = node.tag
        content = convert_wikitext_to_markdown(node.contents.strip())

        if tag_name == 'hr':
            return '---'

        if tag_name == 'br':
            return '<br />'

        if tag_name == 'li':
            return '* '

        if tag_name == 'dd':
            # We use a placeholder so whitespaces don't get stripped
            return '<dd>   '

        if tag_name == 'dt':
            # We use a placeholder so whitespaces don't get stripped
            return '<dt>'

        if tag_name == 'h1':
            return f'# {content}'

        if tag_name == 'h2':
            return f'## {content}'

        if tag_name == 'h3':
            return f'### {content}'

        if tag_name == 'h4':
            return f'#### {content}'

        if tag_name == 'h5':
            return f'##### {content}'

        if tag_name == 's':
            return f'~~{content}~~'

        if tag_name == 'code':
            return f'`{node.contents.strip_code()}`'

        if tag_name == 'ref':
            # If there's content in the ref tag, treat it as a footnote
            if content:
                # Check if the content has already been added as a footnote
                if content in content_to_footnote_map:
                    footnote_key = content_to_footnote_map[content]
                else:
                    footnote_counter += 1
                    footnote_key = str(footnote_counter)

                    footnotes[footnote_key] = content

                    content_to_footnote_map[content] = footnote_key

                if handle_name(node) and handle_name(node) not in name_to_footnote_map:
                    name_to_footnote_map[handle_name(node)] = str(footnote_counter)

                return f'[^{footnote_key}]'  # Return the footnote reference

            # If only name attribute exists, use it to retrieve or assign a footnote number
            if handle_name(node):
                if handle_name(node) not in name_to_footnote_map:
                    footnote_counter += 1
                    name_to_footnote_map[handle_name(node)] = str(footnote_counter)

                # Return the footnote reference based on the name
                return f'[^{name_to_footnote_map[handle_name(node)]}]'

        if tag_name in ['pre', 'syntaxhighlight']:
            return f'\n```{handle_lang(node)}\n{node.contents.strip_code()}\n```\n'

        if tag_name in ['b', 'strong']:
            return f'**{content}**'

        if tag_name in ['i', 'em']:
            return f'*{content}*'

        if tag_name == 'table':
            return handle_table(node)

        return content

    def handle_name(node):
        if node.attributes:
            for attribute in node.attributes:
                if attribute.name == 'name':
                    return str(attribute.value)
        return ''

    def handle_lang(node):
        if node.attributes:
            for attribute in node.attributes:
                if attribute.name == 'lang':
                    return attribute.value
        return ''

    def handle_table(table_node):
        """
        Convert a mwparserfromhell table node to a Markdown table.
        Handle both single-line and multi-line headers/cells, ensuring rows aren't split incorrectly.
        """
        rows = table_node.contents.splitlines()
        markdown_table = []
        header_processed = False
        current_header_row = []
        current_data_row = []

        def clean_cells(cells):
            """Strip newlines and spaces from cells but retain empty ones."""
            return [cell.strip() if cell.strip() else '' for cell in cells if 'style=' not in cell]

        def process_row(row, is_header=False):
            """Process a row of cells and convert to Markdown format."""
            if is_header:
                if row:
                    markdown_table.append(f"| {' | '.join(row)} |")
                    markdown_table.append(f"| {' | '.join(['---'] * len(row))} |")
            else:
                if row:
                    markdown_table.append(f"| {' | '.join(row)} |")

        for row in rows:
            row = row.strip()

            if not row or row.startswith('{') or row.startswith('|-') or '! class=' in row:
                # Skip table attributes (e.g., '{| class="wikitable"') and row separators ('|-')
                # Process the current data row (if any) when we encounter a row separator.
                if current_data_row:
                    process_row(current_data_row)
                    current_data_row = []
                continue

            # Handle wikitext within cells
            row = convert_wikitext_to_markdown(row)

            # Check if the row is a header row (starts with '!')
            if row.startswith('!'):
                # Accumulate header cells until we encounter a new header line or row end
                cells = re.split(r'\s*!!?\s*', row.strip('!'))
                current_header_row.extend(clean_cells(cells))
            elif row.startswith('|'):
                # Accumulate data row cells (until the row is fully processed)
                cells = re.split(r'\s*\|\|?\s*', row.strip('|'))
                current_data_row.extend(clean_cells(cells))

            # If a full header row is complete (e.g., we hit a data row), process it
            if current_header_row and (row.startswith('|') or row.startswith('|-')):
                if not header_processed:
                    process_row(current_header_row, is_header=True)
                    header_processed = True
                current_header_row = []

        # Ensure any unprocessed rows are added at the end (if the last row is incomplete)
        if current_header_row and not header_processed:
            process_row(current_header_row, is_header=True)
        if current_data_row:
            process_row(current_data_row)

        return '\n'.join(markdown_table)

    wikicode = mwparserfromhell.parse(wikitext)
    is_first_category = True
    markdown_lines = []
    current_line = ''
    for node in wikicode.nodes:
        if isinstance(node, mwparserfromhell.nodes.Heading):
            if current_line:
                markdown_lines.append(current_line.strip())
                current_line = ''
            level = node.level
            markdown_lines.append(f"{'#' * level} {node.title.strip_code()}\n")

        elif isinstance(node, mwparserfromhell.nodes.Text):
            text = str(node)
            lines = text.splitlines(keepends=True)  # Keep original newlines
            for line in lines:
                stripped_line = line.strip()
                # Append lines directly
                if stripped_line:
                    current_line += line
                # Preserve newlines if present
                if line.endswith('\n'):
                    markdown_lines.append(current_line.strip())
                    current_line = ''

        elif isinstance(node, mwparserfromhell.nodes.Tag):
            # Process specific HTML tags to Markdown
            processed_content = process_html_tags(node)
            if processed_content:
                no_space_after = ("'", '/', ',', ';', ':', '(', '[', '{', '-', '_')
                if node.tag != 'br' and not current_line.endswith(no_space_after) and not current_line.endswith(' '):
                    current_line += ' '
                current_line += processed_content

        elif isinstance(node, mwparserfromhell.nodes.ExternalLink):
            url = str(node.url)
            label = node.title.strip_code() if node.title else url
            no_space_after = (',', ';', ':', '(', '[', '{', '-', '_')
            if not current_line.endswith(no_space_after) and not current_line.endswith(' '):
                current_line += ' '
            current_line += f'[{label}]({url})'

        elif isinstance(node, mwparserfromhell.nodes.Wikilink):
            target = str(node.title).replace('Special:MyLanguage/Tech:', 'Tech:')
            label = node.text if node.text else target

            is_category = False
            if target.startswith('Category:'):
                is_category = True
                target = mwparserfromhell.parse(target).strip_code()
                label = target

            no_space_after = (',', ';', ':', '(', '[', '{', '-', '_')

            if not current_line.endswith(no_space_after) and not current_line.endswith(' '):
                current_line += ' '

            anchor_replacements = {
                '.28': '',
                '.29': '',

                '(': '',
                ')': '',
                '?': '',
                '!': '',
                ':': '',
                '/': '',
                '.': '',
                ',': '',
                '"': '',
                "'": '',
                '_': '-',
                ' ': '-',
            }

            if target.startswith('#'):
                # Anchor link
                anchor = target
                for old, new in anchor_replacements.items():
                    anchor = anchor.replace(old, new)
                anchor = anchor.lower()
                current_line += f'[{label}]({anchor})'
            else:
                if '#' in target:
                    # Anchor link
                    base_title, anchor = target.split('#', 1)
                else:
                    base_title, anchor = target, None

                formatted_title = base_title.replace(' ', '_').replace('/', '-')
                local_file_path = os.path.join(ensure_sub_directory(), f'{formatted_title}.md')

                # Case-insensitive file existence check
                if file_exists_case_insensitive(local_file_path):
                    # If the local file exists, use the local markdown link
                    formatted_url = f"/tech-docs/{formatted_title.replace(':', '').lower()}"

                    # Append anchor if it exists
                    if anchor:
                        for old, new in anchor_replacements.items():
                            anchor = anchor.replace(old, new)
                        anchor = anchor.lower()
                        formatted_url += f'#{anchor}'

                    # Add the final link
                    current_line += f'[{label}]({formatted_url})'
                else:
                    # Otherwise, link to Miraheze
                    if is_category:
                        # Use a new section with a list for categories
                        if is_first_category:
                            if current_line:
                                markdown_lines.append(current_line.strip())
                                current_line = ''
                            markdown_lines.append('## Categories\n')
                            is_first_category = False
                        current_line += '* '
                    current_line += f"[{label}](https://meta.miraheze.org/wiki/{target.replace(' ', '_')})"

        elif isinstance(node, mwparserfromhell.nodes.Comment):
            if current_line:
                markdown_lines.append(current_line.strip())
                current_line = ''

            if '<!--T:' not in str(node):
                markdown_lines.append(f'\n{str(node).strip()}\n')

        elif isinstance(node, mwparserfromhell.nodes.Template):
            if current_line:
                markdown_lines.append(current_line.strip())
                current_line = ''

            # Keep templates intact in Markdown
            if '\n' in str(node):
                markdown_lines.append(f'```\n{{{{ {node} }}}}\n```')
            elif 'tech navigation' in str(node).lower() or 'hatnote' in str(node).lower():
                markdown_lines.append(f'\n`{{{{ {node} }}}}`')
            else:
                current_line += f'`{{{{ {node} }}}}`'

        elif isinstance(node, mwparserfromhell.nodes.HTMLEntity):
            current_line += str(node)

        else:
            current_line += str(node)

    # Flush any remaining inline content to markdown_lines
    if current_line:
        markdown_lines.append(current_line.strip())

    return clean_markdown(markdown_lines)


def clean_markdown(markdown_lines):
    # Wrap lines starting with <dt> with **{line}**
    markdown_lines = [f'\n**{line.strip()}**\n' if line.startswith('<dt>') else line for line in markdown_lines]
    markdown_text = '\n'.join(markdown_lines)

    replacements = {
        # Fix list hierarchy format
        '* * * * ': '         * ',
        '* * * ': '      * ',
        '* * ': '   * ',
        '* - `': '  * `',  # TODO: Improve, this is currently very much an edge case for Tech:Removing an extension
        # Remove magic words
        '__NOTOC__\n': '',
        '__NOINDEX__\n': '',
        '__FORCETOC__\n': '',
        ' __NOINDEX__': '',
        # Fix template nodes
        '\n`{{': ' `{{',
        # Remove empty comments
        '<!---->\n': '',
        '<!---->': '',
        # Replace &nbsp; with a space
        '&nbsp;': ' ',
    }

    # Apply replacements
    for pattern, replacement in replacements.items():
        markdown_text = markdown_text.replace(pattern, replacement)

    # Replace 3 or more consecutive newlines with 2
    markdown_text = re.sub(r'\n{3,}', '\n\n', markdown_text)

    # Remove placeholder for <dd> and <dt> tags
    markdown_text = markdown_text.replace('<dd>', '').replace('<dt>', '')

    def replace_outside_code_blocks(text):
        """Replace spaces but skip inside code blocks"""
        in_code_block = False

        def replace_spaces(match):
            nonlocal in_code_block
            line = match.group(0)
            if line.startswith('```'):
                in_code_block = not in_code_block
            if not in_code_block:
                # Replace extra spaces only after the first non-space character in the line
                return re.sub(r'(^\s*\S.*?)([ \u00A0]{2,})', lambda m: m.group(1) + ' ', line)
            return line

        return re.sub(r'^.*$', replace_spaces, text, flags=re.M)

    # Apply space trimming outside of code blocks
    markdown_text = replace_outside_code_blocks(markdown_text)

    # Remove extra whitespace at the start of lines wrapped in ** (after <dt>)
    markdown_text = re.sub(r'^\*\* ', '**', markdown_text, flags=re.M)

    # Fix tables
    markdown_text = re.sub(r'^\| \|', '|', markdown_text, flags=re.M)

    return markdown_text


def file_exists_case_insensitive(file_path):
    directory, file_name = os.path.split(file_path)
    if not os.path.exists(directory):
        return False

    # Compare case-insensitive file names
    return any(existing_file.lower() == file_name.lower() for existing_file in os.listdir(directory))


def update_local_repo():
    if not os.path.exists(LOCAL_REPO_PATH):
        Repo.clone_from(GITHUB_REPO_URL, LOCAL_REPO_PATH, env={'GIT_SSH_COMMAND': f'ssh -i {SSH_PRIVATE_KEY_PATH} -F /dev/null -o ProxyCommand="nc -X connect -x {HTTP_PROXY} %h %p"'})
    else:
        repo = Repo(LOCAL_REPO_PATH)
        repo.git.pull(env={'GIT_SSH_COMMAND': f'ssh -i {SSH_PRIVATE_KEY_PATH} -F /dev/null -o ProxyCommand="nc -X connect -x {HTTP_PROXY} %h %p"'})


def ensure_sub_directory():
    """Ensure that the sub-directory exists."""
    full_path = os.path.join(LOCAL_REPO_PATH, SUB_DIRECTORY)
    if not os.path.exists(full_path):
        os.makedirs(full_path)
    return full_path


def write_content_to_file(title, content):
    """Write page content to a markdown file in the sub-directory."""
    sub_dir_path = ensure_sub_directory()
    filename = title.replace(' ', '_').replace('/', '-') + '.md'
    filepath = os.path.join(sub_dir_path, filename)
    url = f"https://meta.miraheze.org/wiki/{title.replace(' ', '_')}"
    header = f'---\ntitle: {title}\n---\n\n'
    footer = f'\n\n----\n**[Go to Source &rarr;]({url})**'

    with open(filepath, 'w', encoding='utf-8') as file:
        file.write(header + content + footer)


def delete_files_not_in_pages(pages):
    """Delete files in the sub-directory that are not in the list of pages."""
    sub_dir_path = ensure_sub_directory()
    existing_files = {f for f in os.listdir(sub_dir_path) if f.endswith('.md')}
    page_files = {page['title'].replace(' ', '_').replace('/', '-') + '.md' for page in pages}
    files_to_delete = existing_files - page_files

    for file in files_to_delete:
        os.remove(os.path.join(sub_dir_path, file))


def commit_and_push_changes():
    repo = Repo(LOCAL_REPO_PATH)
    with repo.config_writer() as git_config:
        git_config.set_value('user', 'email', GIT_USER_EMAIL)
        git_config.set_value('user', 'name', GIT_USER_NAME)
    repo.git.add(A=True)  # Add all changes
    utctime = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    commit_message = f'Bot: Auto-update Tech namespace pages {utctime}'
    repo.index.commit(commit_message)
    origin = repo.remote(name='origin')
    origin.push(env={'GIT_SSH_COMMAND': f'ssh -i {SSH_PRIVATE_KEY_PATH} -F /dev/null -o ProxyCommand="nc -X connect -x {HTTP_PROXY} %h %p"'})


def mirror_tech_pages_to_github():
    print('Fetching Tech namespace pages...')
    pages = fetch_tech_pages()
    update_local_repo()  # Clone or pull latest changes
    delete_files_not_in_pages(pages)  # Delete old files not present in API response
    for page in pages:
        title = page['title']
        print(f'Processing page: {title}')
        content = fetch_page_content(title)
        markdown_content = convert_wikitext_to_markdown(content)
        write_content_to_file(title, markdown_content + generate_footnotes())
        reset_footnotes()  # Reset footnote data for next page
    commit_and_push_changes()
    print('Successfully updated GitHub repository.')


if __name__ == '__main__':
    mirror_tech_pages_to_github()
