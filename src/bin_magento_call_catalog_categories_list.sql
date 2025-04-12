delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_catalog_categories_list$$

CREATE PROCEDURE `bin_magento_call_catalog_categories_list`(IN cmd VARCHAR(255))
COMMENT 'Listing all the Categories, use `--help` to see additional commands'
BEGIN
    DECLARE stmt TEXT;
    DECLARE column_name VARCHAR(9);
    SET column_name = bin_magento_get_entity_column();

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`catalog:categories:list --help`                           - ℹ️ To see this help' AS 'help'
                    UNION ALL
                SELECT CONCAT('`catalog:categories:list`                                     ',
                       '- ℹ️ [slow command] It will list all the categories in alphabetical order') AS 'help';
            END;
        ELSE
            BEGIN
                SET stmt=CONCAT(
                        REPLACE(
                            bin_magento_get_eav('catalog_category'),
                            'ea.*,',
                            CONCAT(
                                    'DISTINCT ce.path, ce.position, ce.level, ce.', column_name , ', ce.position,
                                        CONCAT(REPEAT("   ", ce.level), "- ", CASE
                                            WHEN ea.backend_type = ''varchar'' THEN cev.value
                                            WHEN ea.backend_type = ''int'' THEN cei.value
                                            WHEN ea.backend_type = ''text'' THEN cet.value
                                            WHEN ea.backend_type = ''decimal'' THEN ced.value
                                            WHEN ea.backend_type = ''datetime'' THEN cedt.value
                                          END) view,'
                            )
                        ),
                        ' WHERE
			                ea.attribute_code = "name" ',
                        'ORDER BY
			                ce.path'
                    );
                SELECT stmt;
                EXECUTE IMMEDIATE stmt;
            END;
    END CASE;


END$$

