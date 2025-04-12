DELIMITER $$

DROP PROCEDURE IF EXISTS bin_magento_call_indexer_list$$

CREATE PROCEDURE `bin_magento_call_indexer_list`(IN cmd VARCHAR(255))
    COMMENT 'List and manage Magento indexes'
BEGIN
    DECLARE filter_str VARCHAR(255) DEFAULT NULL;
    DECLARE is_clear BOOLEAN DEFAULT FALSE;
    DECLARE is_mode_change BOOLEAN DEFAULT FALSE;
    DECLARE new_mode VARCHAR(50) DEFAULT NULL;
    DROP TEMPORARY TABLE IF EXISTS temp_index_results;
    CREATE TEMPORARY TABLE temp_index_results (
                                                  Index_ID VARCHAR(255),
                                                  Title VARCHAR(255),
                                                  Status VARCHAR(50),
                                                  Mode VARCHAR(50),
                                                  Last_Updated DATETIME,
                                                  Indexed_Data VARCHAR(255)
    );

    main_block: BEGIN
        IF cmd = '--help' THEN
            BEGIN
                SELECT ':::' AS 'Help' UNION ALL
                SELECT '::: Use commands like:' AS 'Help' UNION ALL
                SELECT ':::' AS 'Help' UNION ALL
                SELECT '`indexer:list --help`                - ℹ️ To see this help' AS 'Help' UNION ALL
                SELECT '`indexer:list`                       - ℹ️ List all Magento indexes' AS 'Help' UNION ALL
                SELECT '`indexer:list <filter>`              - ℹ️ Filter indexes by ID (e.g., `salesrule_rule`)' AS 'Help' UNION ALL
                SELECT '`indexer:list --clear <filter>`      - ℹ️ Reset index status to invalid (e.g., `--clear salesrule_rule`)' AS 'Help' UNION ALL
                SELECT '`indexer:list --mode=schedule <filter>` - ℹ️ Set index to Update by Schedule' AS 'Help' UNION ALL
                SELECT '`indexer:list --mode=realtime <filter>` - ℹ️ Set index to Update on Save' AS 'Help';
            END;
        ELSE
            BEGIN
                IF LOCATE('--clear', cmd) > 0 THEN
                    SET is_clear = TRUE;
                    SET cmd = TRIM(REPLACE(cmd, '--clear', ''));
                END IF;

                IF LOCATE('--mode=', cmd) > 0 THEN
                    SET is_mode_change = TRUE;
                    SET new_mode = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--mode=', -1), ' ', 1));
                    SET cmd = TRIM(REPLACE(cmd, CONCAT('--mode=', new_mode), ''));
                    IF new_mode NOT IN ('realtime', 'schedule') THEN
                        SELECT CONCAT('Invalid mode: `', new_mode, '`. Use `realtime` or `schedule`.') AS 'Error';
                        DROP TEMPORARY TABLE temp_index_results;
                        LEAVE main_block;
                    END IF;
                END IF;

                SET filter_str = TRIM(cmd);
                IF filter_str = '' THEN
                    SET filter_str = NULL;
                END IF;

                INSERT INTO temp_index_results (Index_ID, Status, Last_Updated)
                SELECT
                    indexer_id,
                    status,
                    updated
                FROM indexer_state
                WHERE filter_str IS NULL OR indexer_id LIKE CONCAT('%', filter_str, '%');

                UPDATE temp_index_results tir
                SET Mode = CASE
                               WHEN EXISTS (
                                   SELECT 1
                                   FROM information_schema.tables
                                   WHERE table_schema = DATABASE()
                                     AND table_name = CONCAT(tir.Index_ID, '_cl')
                               ) THEN 'Update by Schedule'
                               ELSE 'Update on Save'
                    END
                WHERE tir.Index_ID IS NOT NULL;

                UPDATE temp_index_results tir
                SET
                    Title = CASE
                                WHEN Index_ID = 'design_config_grid' THEN 'Design Config Grid'
                                WHEN Index_ID = 'customer_grid' THEN 'Customer Grid'
                                WHEN Index_ID = 'catalog_category_product' THEN 'Category Products'
                                WHEN Index_ID = 'catalog_product_category' THEN 'Product Categories'
                                WHEN Index_ID = 'catalog_product_price' THEN 'Product Price'
                                WHEN Index_ID = 'catalog_product_attribute' THEN 'Product EAV'
                                WHEN Index_ID = 'catalogsearch_fulltext' THEN 'Catalog Search'
                                WHEN Index_ID = 'cataloginventory_stock' THEN 'Stock'
                                WHEN Index_ID = 'catalogrule_rule' THEN 'Catalog Rule Product'
                                WHEN Index_ID = 'catalogrule_product' THEN 'Catalog Product Rule'
                                WHEN Index_ID = 'salesrule_rule' THEN 'Sales Rule'
                                ELSE CONCAT('Unknown (', Index_ID, ')')
                        END,
                    Indexed_Data = CASE
                                       WHEN Index_ID = 'design_config_grid' THEN 'Design configurations'
                                       WHEN Index_ID = 'customer_grid' THEN 'Customer data'
                                       WHEN Index_ID = 'catalog_category_product' THEN 'Category-product relationships'
                                       WHEN Index_ID = 'catalog_product_category' THEN 'Product-category relationships'
                                       WHEN Index_ID = 'catalog_product_price' THEN 'Product prices'
                                       WHEN Index_ID = 'catalog_product_attribute' THEN 'Product EAV attributes'
                                       WHEN Index_ID = 'catalogsearch_fulltext' THEN 'Searchable product data'
                                       WHEN Index_ID = 'cataloginventory_stock' THEN 'Stock levels'
                                       WHEN Index_ID = 'catalogrule_rule' THEN 'Catalog rules'
                                       WHEN Index_ID = 'catalogrule_product' THEN 'Catalog rule products'
                                       WHEN Index_ID = 'salesrule_rule' THEN 'Sales rules (cart rules)'
                                       ELSE 'Unknown'
                        END
                WHERE tir.Index_ID IS NOT NULL;

                IF is_clear AND filter_str IS NOT NULL THEN
                    UPDATE indexer_state
                    SET status = 'invalid'
                    WHERE indexer_id LIKE CONCAT('%', filter_str, '%');
                    SELECT CONCAT('Reset index(es) matching `', filter_str, '` to invalid.') AS 'Result';
                    DROP TEMPORARY TABLE temp_index_results;
                    LEAVE main_block;
                END IF;

                IF is_mode_change AND filter_str IS NOT NULL THEN
                    IF new_mode = 'schedule' THEN
                        SET @create_cl = CONCAT(
                                'CREATE TABLE IF NOT EXISTS `', filter_str, '_cl` (',
                                '`version_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, ',
                                '`entity_id` INT NOT NULL, ',
                                'PRIMARY KEY (`version_id`), ',
                                'UNIQUE KEY `entity_id` (`entity_id`)',
                                ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
                                         );
                        EXECUTE IMMEDIATE @create_cl;

                        INSERT INTO mview_state (view_id, mode, status, updated, version_id)
                        SELECT filter_str, 'enabled', 'idle', NOW(), 0
                        ON DUPLICATE KEY UPDATE mode = 'enabled', status = 'idle', updated = NOW();
                    ELSEIF new_mode = 'realtime' THEN
                        SET @drop_cl = CONCAT('DROP TABLE IF EXISTS `', filter_str, '_cl`');
                        EXECUTE IMMEDIATE @drop_cl;
                        DELETE FROM mview_state WHERE view_id = filter_str;
                    END IF;

                    SELECT CONCAT('Set mode of index(es) matching `', filter_str, '` to `', new_mode, '`.') AS 'Result';
                    DROP TEMPORARY TABLE temp_index_results;
                    LEAVE main_block;
                END IF;

                SELECT
                    Index_ID AS 'Index ID',
                    Title,
                    Status,
                    Mode,
                    Last_Updated AS 'Last Updated',
                    Indexed_Data AS 'Indexed Data'
                FROM temp_index_results
                ORDER BY Index_ID;
                DROP TEMPORARY TABLE temp_index_results;
            END;
        END IF;
    END main_block;
END$$
