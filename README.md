# SQL bin/magento

Run Magento 2 commands directly in MySQL without PHP for dramatically faster execution.

Please import the full .sql file to your database, and run:
``` call bin_magento(''); ```
to execute it.

You can easily remove the imported file by:

``` call bin_magento('uninstall'); ```
