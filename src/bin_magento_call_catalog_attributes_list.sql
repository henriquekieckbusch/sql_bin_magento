delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_catalog_attributes_list$$

CREATE PROCEDURE `bin_magento_call_catalog_attributes_list`(IN cmd VARCHAR(255))
    COMMENT 'Listing all the Product attributes, use `--help` to see additional commands like `--full` to get more details'
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
                SELECT '`catalog:attributs:list --help`   - ℹ️ To see this help" AS \'help\''
                    UNION ALL
                SELECT CONCAT('`catalog:attributs:list`             ',
                       '- ℹ️ It will list all the product attribute codes in alphabetical order') AS 'help'
                    UNION ALL
                SELECT CONCAT('`catalog:attributs:list --full`     ',
                       '- ℹ️ It will list all the product attribute codes in alphabetical order and ',
                       'showing full columns and details') AS 'help';
            END;
        WHEN  '--full' THEN
            BEGIN
                SET @stmt=CONCAT(
                        'SELECT r.* FROM (', bin_magento_get_eav('catalog_product'), ') as r ',
                        'GROUP BY r.attribute_code ORDER BY r.attribute_code ASC;'
                    );
                EXECUTE IMMEDIATE @stmt;
            END;
        ELSE
            BEGIN
                SET @stmt=CONCAT(
                        'SELECT r.attribute_code FROM (', bin_magento_get_eav('catalog_product'), ') as r ',
                        'GROUP BY r.attribute_code ORDER BY r.attribute_code ASC;'
                    );
                EXECUTE IMMEDIATE @stmt;
            END;
        END CASE;
END$$

