import os
import requests
from git import Repo
from datetime import datetime
import mwparserfromhell
import re

MEDIAWIKI_API_URL = 'https://meta.miraheze.org/w/api.php'
GITHUB_REPO_URL = 'git@github.com:miraheze/statichelp.git'
LOCAL_REPO_PATH = '/home/universalomega/statichelp'
SUB_DIRECTORY = 'content/tech-docs'
NAMESPACE = 1600  # Tech namespace ID
USER_AGENT = 'TechNamespaceBot/1.0 (https://github.com/miraheze/statichelp/tree/main/content/tech-docs)'

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


def convert_wikitext_to_markdown(wikitext):
    """
    Convert wikitext to markdown using mwparserfromhell with custom handling.
    """
    wikitext = preprocess_wikitext(wikitext)
    wikicode = mwparserfromhell.parse(wikitext)
    markdown_lines = []
    current_line = ''
    
    for node in wikicode.nodes:
        current_line = process_node(node, current_line, markdown_lines)
    
    if current_line:
        markdown_lines.append(current_line.strip())
    
    return clean_markdown(markdown_lines)


def preprocess_wikitext(wikitext):
    """Preprocess wikitext before conversion."""
    return re.sub(r'</?(tvar|noinclude|includeonly).*?>', '', wikitext)


def process_node(node, current_line, markdown_lines):
    """Process each type of wikitext node."""
    if isinstance(node, mwparserfromhell.nodes.Heading):
        return process_heading_node(node, current_line, markdown_lines)

    if isinstance(node, mwparserfromhell.nodes.Text):
        return process_text_node(node, current_line, markdown_lines)

    if isinstance(node, mwparserfromhell.nodes.Tag):
        return process_html_tag_node(node, current_line)

    if isinstance(node, mwparserfromhell.nodes.ExternalLink):
        return process_external_link_node(node, current_line)

    if isinstance(node, mwparserfromhell.nodes.Wikilink):
        return process_wikilink_node(node, current_line)

    if isinstance(node, mwparserfromhell.nodes.Template):
        return process_template_node(node, current_line, markdown_lines)

    if isinstance(node, mwparserfromhell.nodes.Comment):
        return process_comment_node(node, markdown_lines)

    if isinstance(node, mwparserfromhell.nodes.HTMLEntity):
        return current_line + str(node)

    return current_line + str(node)


def process_heading_node(node, current_line, markdown_lines):
    """Process heading nodes."""
    if current_line:
        markdown_lines.append(current_line.strip())
    level = node.level
    markdown_lines.append(f"{'#' * level} {node.title.strip_code()}\n")
    return ''


def process_text_node(node, current_line, markdown_lines):
    """Process text nodes, keeping original newlines."""
    text = str(node)
    lines = text.splitlines(keepends=True)
    
    for line in lines:
        stripped_line = line.strip()
        if stripped_line:
            current_line += line
        if line.endswith('\n'):
            markdown_lines.append(current_line.strip())
            current_line = ''
    
    return current_line


def process_html_tag_node(node, current_line):
    """Process HTML tag nodes to markdown."""
    processed_content = process_html_tags(node)
    no_space_after = ("'", '/', ',', ';', ':', '(', '[', '{', '-', '_')
    if node.tag != 'br' and not current_line.endswith(no_space_after) and not current_line.endswith(' '):
        current_line += ' '
    return current_line + processed_content


def process_external_link_node(node, current_line):
    """Process external link nodes."""
    url = str(node.url)
    label = node.title.strip_code() if node.title else url
    no_space_after = (',', ';', ':', '(', '[', '{', '-', '_')
    if not current_line.endswith(no_space_after) and not current_line.endswith(' '):
        current_line += ' '
    return current_line + f'[{label}]({url})'


def process_wikilink_node(node, current_line):
    """Process wiki link nodes."""
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
    return current_line


def process_template_node(node, current_line, markdown_lines):
    """Process template nodes."""
    if current_line:
        markdown_lines.append(current_line.strip())
    
    if '\n' in str(node):
        markdown_lines.append(f'```\n{{{{ {node} }}}}\n```')
    else:
        current_line += f'`{{{{ {node} }}}}`'
    
    return current_line


def process_comment_node(node, markdown_lines):
    """Process comment nodes."""
    if '<!--T:' not in str(node):
        markdown_lines.append(f'\n{str(node).strip()}\n')
    return ''


def process_html_tags(node):
    """Convert specific HTML tags to Markdown."""
    tag_name = node.tag
    content = convert_wikitext_to_markdown(node.contents.strip())
    
    tag_conversions = {
        'hr': '---',
        'br': '<br />',
        'li': '* ',
        'dd': '<dd>   ',
        'dt': '<dt>',
        'h1': f'# {content}',
        'h2': f'## {content}',
        'h3': f'### {content}',
        'h4': f'#### {content}',
        'h5': f'##### {content}',
        's': f'~~{content}~~',
        'code': f'`{node.contents.strip_code()}`',
        'ref': f'<sub>(*reference:* {content})</sub>' if content else '',
        'pre': f'\n```{handle_lang(node)}\n{node.contents.strip_code()}\n```\n',
        'b': f'**{content}**',
        'strong': f'**{content}**',
        'i': f'*{content}*',
        'em': f'*{content}*',
        'table': handle_table(node),
    }
    
    return tag_conversions.get(tag_name, content)


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


def handle_lang(node):
    """Handle lang attribute extraction."""
    if node.attributes:
        for attribute in node.attributes:
            if attribute.name == 'lang':
                return attribute.value
    return ''


def clean_markdown(markdown_lines):
    """Clean up the markdown lines after conversion."""
    # Wrap lines starting with <dt> with **{line}**
    markdown_lines = [f'\n**{line.strip()}**\n' if line.startswith('<dt>') else line for line in markdown_lines]
    markdown_text = '\n'.join(markdown_lines)

    replacements = {
        # Fix list hierarchy format
        '* * * * ': '         * ',
        '* * * ': '      * ',
        '* * ': '   * ',
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
        Repo.clone_from(GITHUB_REPO_URL, LOCAL_REPO_PATH)
    else:
        repo = Repo(LOCAL_REPO_PATH)
        repo.git.pull()


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
    repo.git.add(A=True)  # Add all changes
    commit_message = f'Auto-update Tech namespace pages {datetime.now()}'
    repo.index.commit(commit_message)
    origin = repo.remote(name='origin')
    origin.push()


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
        write_content_to_file(title, markdown_content)
    commit_and_push_changes()
    print('Successfully updated GitHub repository.')


if __name__ == '__main__':
    mirror_tech_pages_to_github()
