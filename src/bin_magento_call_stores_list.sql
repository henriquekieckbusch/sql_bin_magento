DELIMITER $$

DROP PROCEDURE IF EXISTS `bin_magento_call_stores_list`$$

CREATE PROCEDURE `bin_magento_call_stores_list`(IN cmd VARCHAR(255))
    COMMENT 'Listing all the stores, use `--help` to see additional commands'
BEGIN
    CASE cmd
        WHEN '--help' THEN
            BEGIN
                SELECT ':::' AS 'help' UNION ALL
                SELECT '::: Use commands like:' AS 'help' UNION ALL
                SELECT ':::' AS 'help' UNION ALL
                SELECT '`stores:list --help` - ℹ️ To see this help' AS 'help' UNION ALL
                SELECT '`stores:list` - ℹ️ It lists all the stores with their URLs' AS 'help';
            END;
        ELSE
            BEGIN
                SELECT
                    s.store_id AS `ID`,
                    s.code AS `Code`,
                    s.name AS `Name`,
                    CASE s.is_active
                        WHEN 1 THEN 'Active'
                        ELSE 'Inactive'
                        END AS `Status`,
                    g.name AS `Store Group`,
                    w.name AS `Website`,
                    COALESCE(
                            (SELECT value FROM core_config_data
                             WHERE path = 'web/secure/base_url'
                               AND scope = 'stores'
                               AND scope_id = s.store_id
                             LIMIT 1),
                            (SELECT value FROM core_config_data
                             WHERE path = 'web/secure/base_url'
                               AND scope = 'default'
                             LIMIT 1)
                    ) AS `URL`
                FROM store s
                         JOIN store_group g ON s.group_id = g.group_id
                         JOIN store_website w ON g.website_id = w.website_id
                ORDER BY w.name ASC, g.name ASC, s.name ASC;
            END;
        END CASE;
END$$
