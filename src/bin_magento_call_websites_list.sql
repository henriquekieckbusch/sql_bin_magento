DELIMITER $$

DROP PROCEDURE IF EXISTS `bin_magento_call_websites_list`$$

CREATE PROCEDURE `bin_magento_call_websites_list`(IN cmd VARCHAR(255))
    COMMENT 'Listing all the websites, use `--help` to see additional commands'
BEGIN
    CASE cmd
        WHEN '--help' THEN
            BEGIN
                SELECT ':::' AS 'help' UNION ALL
                SELECT '::: Use commands like:' AS 'help' UNION ALL
                SELECT ':::' AS 'help' UNION ALL
                SELECT '`websites:list --help` - ℹ️ To see this help' AS 'help' UNION ALL
                SELECT '`websites:list` - ℹ️ It lists all the websites with their URLs' AS 'help';
            END;
        ELSE
            BEGIN
                SELECT
                    sw.website_id AS `ID`,
                    sw.code AS `Code`,
                    sw.name AS `Name`,
                    sw.is_default AS `Is Default`,
                    COALESCE(
                            (SELECT value FROM core_config_data
                             WHERE path = 'web/secure/base_url'
                               AND scope = 'websites'
                               AND scope_id = sw.website_id
                             LIMIT 1),
                            (SELECT value FROM core_config_data
                             WHERE path = 'web/secure/base_url'
                               AND scope = 'default'
                             LIMIT 1)
                    ) AS `URL`
                FROM store_website sw
                ORDER BY sw.name ASC;
            END;
        END CASE;
END$$
