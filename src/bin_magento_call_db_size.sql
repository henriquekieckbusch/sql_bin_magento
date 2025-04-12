delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_db_size$$

CREATE PROCEDURE `bin_magento_call_db_size`(IN cmd VARCHAR(255))
    COMMENT 'This will show your current database size'
BEGIN
    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`db:size --help`      - ℹ️ To see this help' AS 'help'
                    UNION ALL
                SELECT '`db:size`             - ℹ️ It will show the current Database size' AS 'help';
            END;
        ELSE
            BEGIN
                SELECT
                    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
                        ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS 'Size (GB)',
                        COUNT(DISTINCT table_name) AS 'Number of tables',
                        SUM(table_rows) AS 'Number of rows',
                        MIN(create_time) AS 'Created date',
                        MAX(update_time) AS 'Last update date'
                FROM
                    information_schema.TABLES
                WHERE
                        table_schema = DATABASE();
            END;
    END CASE;
END$$

