SQL bin/magento
Run Magento 2 commands directly in MySQL without PHP for dramatically faster execution.

To execute Magento 2 CLI-like commands directly in your MySQL database without needing PHP or the Magento application layer. The result? Lightning-fast command execution and direct database insights.

Benefits
Performance: Execute commands multiple times faster than traditional bin/magento methods

Simplicity: Run commands directly in your MySQL client or database management tool

Transparency: See the actual SQL queries behind Magento operations

Efficiency: View comprehensive data (like product information with all attributes as columns)

Debugging: Quickly investigate database issues without leaving your database environment

Installation
Import the SQL file into your Magento database:

sql
-- Download and import the SQL file
SOURCE /path/to/bin_magento_v1.sql;

-- Or directly from GitHub using MySQL source capability if available
-- SOURCE https://raw.githubusercontent.com/henriquekieckbusch/sql_bin_magento/main/bin_magento_v1.sql;
That's it! Start using the commands immediately.

Usage
Run commands using the bin_magento stored procedure:

sql
CALL bin_magento('command:name:here');
Getting Help
Display available commands:

sql
CALL bin_magento('');
Get help for a specific command:

sql
CALL bin_magento('command:name --help');
Command Examples
Admin User Management
List all admin users:

sql
CALL bin_magento('admin:user:list');
Product Management
List products with basic information:

sql
CALL bin_magento('catalog:products:list');
List products with all attributes as columns:

sql
CALL bin_magento('catalog:products:list --full');
See the SQL query behind a command:

sql
CALL bin_magento('catalog:products:list --full --sql');
Indexer Management
View indexer status:

sql
CALL bin_magento('indexer:status');
Change indexer mode:

sql
CALL bin_magento('indexer:set-mode realtime');
CALL bin_magento('indexer:set-mode schedule');
Important Considerations
Database Safety: You're working directly with the database, so take appropriate precautions

Read vs Write: Most commands are view-only, but verify before executing write operations

Cache Awareness: Database changes may not reflect in cached data (Redis, etc.) without additional cache clearing

Testing: Always test in a development environment before using in production

Uninstallation
To remove the tool from your database:

sql
CALL bin_magento('uninstall');

Contributing
Contributions are welcome! If you have ideas for new commands or improvements:

Fork the repository

Create your feature branch (git checkout -b feature/amazing-command)

Commit your changes (git commit -m 'Add amazing command')

Push to the branch (git push origin feature/amazing-command)

Open a Pull Request

License
This project is licensed under the MIT License - see the LICENSE file for details.

About
Created by Henrique Kieckbusch in 2019 and publicly released in 2025.

If you find this tool helpful, please star the repository and share with other Magento developers!
