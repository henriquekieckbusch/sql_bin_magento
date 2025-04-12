delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_catalog_products_list$$

CREATE
    PROCEDURE bin_magento_call_catalog_products_list(IN cmd varchar(255))
    COMMENT 'Listing all the Products, use `--help` to see additional commands'
BEGIN
    DECLARE isFull SMALLINT;
    DECLARE isSQLOnly SMALLINT;
    DECLARE stmt TEXT;
    DECLARE pageSize INT DEFAULT 12;
    DECLARE page INT DEFAULT 1;
    DECLARE column_name VARCHAR(9);
    SET column_name = bin_magento_get_entity_column();

    SET isFull = LOCATE('--full', cmd) > 0;
    SET cmd = TRIM(REPLACE(cmd, '--full', ''));
    SET isSQLOnly = LOCATE('--sql', cmd) > 0;
    SET cmd = TRIM(REPLACE(cmd, '--sql', ''));
    IF LOCATE('--pageSize=', cmd) > 0 THEN
        SET pageSize = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--pageSize=', -1), ' ', 1) AS SIGNED);
        SET cmd = TRIM(REPLACE(cmd, CONCAT('--pageSize=', pageSize), ''));
        SET page = 1;
    END IF;
    IF LOCATE('--page=', cmd) > 0 THEN
        SET page = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--page=', -1), ' ', 1) AS SIGNED);
        SET cmd = TRIM(REPLACE(cmd, CONCAT('--page=', page), ''));
    END IF;

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                UNION ALL
                SELECT ':::' AS 'help'
                UNION ALL
                SELECT '`catalog:products:list --help`                 - ℹ️ To see this help' AS 'help'
                UNION ALL
                SELECT CONCAT('`catalog:products:list`                        ',
                       '- ℹ️ [slow command] It will list all the product ',
                       'id, sku, name, price, type, attribute_set and status in alphabetical order') AS 'help'
                UNION ALL
                SELECT CONCAT('`<command> --full`                             ',
                       '- ℹ️ [slow command] It will list all the product attribute codes as column') AS 'help'
                UNION ALL
                SELECT CONCAT('`catalog:products:list <website_code>`         ',
                       '- ℹ️ [slow command] For that website_code, It will list all the product ',
                       'id, sku, name, price, type, attribute_set and status in alphabetical order') AS 'help'
                UNION ALL
                SELECT CONCAT('`<command> --pageSize=<number>`                ',
                              '- ℹ️ To set the number of items per page, default is 12')
                           AS 'help'
                UNION ALL
                SELECT CONCAT('`<command> --page=<number>`                    ',
                              '- ℹ️ To get just specific page (no space around `=`), ',
                              'example: `catalog:products:list --pageSize=20 --page=1 --full`')
                           AS 'help'
                UNION ALL
                SELECT CONCAT('`<command> --sql`                              ',
                              '- ℹ️ It will render the SQL query, not the result')
                           AS 'help';
            END;
        ELSE
            executing_sql: BEGIN

                DECLARE websiteId INT DEFAULT -1;
                IF cmd <> '' THEN
                    SELECT website_id INTO websiteId FROM store_website WHERE code = cmd OR name = cmd LIMIT 1;
                    IF websiteId < 0 THEN
                        SELECT CONCAT('Sorry, I didnt find any Website with the code or name `', cmd,'`') AS 'Ooops!';
                        LEAVE executing_sql;
                    END IF;
                END IF;

                IF isFull > 0 THEN
                    BEGIN
                        DECLARE attribute_code VARCHAR(255);
                        DECLARE attribute_id INT;
                        DECLARE attribute_type VARCHAR(255);
                        DECLARE done INT DEFAULT 0;
                        DECLARE cur CURSOR FOR SELECT ea.attribute_code, ea.attribute_id, ea.backend_type
                                                   FROM eav_attribute AS ea
                                                            JOIN eav_entity_type AS eet
                                                                ON ea.entity_type_id = eet.entity_type_id
                                                   WHERE eet.entity_type_code = 'catalog_product';
                        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
                        SET @query = 'SELECT e.entity_id, e.sku';

                        OPEN cur;
                            read_loop: LOOP
                                FETCH cur INTO attribute_code, attribute_id, attribute_type;
                                IF done THEN
                                    LEAVE read_loop;
                                END IF;

                                IF attribute_type = 'static' THEN
                                    CASE attribute_code
                                        WHEN 'category_ids' THEN
                                            SET @query = CONCAT
                                                (
                                                    @query,
                                                    ', (SELECT GROUP_CONCAT(ccp.category_id)',
                                                    ' FROM catalog_category_product AS ccp',
                                                    ' WHERE ccp.product_id = e.entity_id) AS `',attribute_code, '`'
                                                );
                                        WHEN 'media_gallery' THEN
                                            SET @query = CONCAT
                                                (
                                                    @query,
                                                    ', (SELECT GROUP_CONCAT(mg.value)',
                                                    ' FROM catalog_product_entity_media_gallery AS mg',
                                                    ' JOIN catalog_product_entity_media_gallery_value_to_entity AS mgvte',
                                                    '   ON mg.value_id = mgvte.value_id',
                                                    ' WHERE mgvte.', column_name ,' = e.entity_id) AS `',attribute_code, '`'
                                                );
                                        ELSE
                                            IF EXISTS (
                                                SELECT 1
                                                FROM INFORMATION_SCHEMA.COLUMNS
                                                WHERE TABLE_SCHEMA = DATABASE()
                                                  AND TABLE_NAME = 'catalog_product_entity'
                                                  AND COLUMN_NAME = attribute_code
                                            ) THEN
                                                SET @query = CONCAT(
                                                        @query,
                                                        ', (SELECT ', attribute_code, ' FROM catalog_product_entity',
                                                        ' WHERE entity_id = e.entity_id',
                                                        ' LIMIT 1) AS `', attribute_code, '`'
                                                    );
                                            END IF;
                                    END CASE;
                                ELSE
                                    SET @query = CONCAT
                                        (
                                            @query,
                                            ', (SELECT value FROM catalog_product_entity_',
                                            attribute_type,
                                            ' WHERE entity_id = e.entity_id AND attribute_id = ',
                                            attribute_id, ' LIMIT 1) AS `', attribute_code, '`'
                                        );
                                END IF;
                            END LOOP;
                        CLOSE cur;

                        SET @query = CONCAT(
                            @query,
                            ' FROM catalog_product_entity AS e ',
                            IF(websiteId > -1, CONCAT(' WHERE (SELECT count(*) FROM catalog_product_website',
                                ' WHERE product_id = e.entity_id AND website_id = ', websiteId,') > 0'),
                                ''
                            ),
                            IF(
                                page > -1,
                                CONCAT(' LIMIT ', page, ', ', pageSize),
                                ''
                            )
                        );
                        IF isSQLOnly > 0 THEN
                            SELECT TRIM(@query) AS 'SQL query';
                        ELSE
                            EXECUTE IMMEDIATE @query;
                        END IF;
                    END;
                ELSE
                    BEGIN
                        SET stmt=CONCAT(
                                REPLACE(
                                        bin_magento_get_eav('catalog_product'),
                                        'ea.*,',
                                        CONCAT(
                                            'ce.entity_id, ce.sku,
                                            (
                                                SELECT ed.value
                                                FROM catalog_product_entity AS e
                                                JOIN catalog_product_entity_decimal AS ed ON e.entity_id = ed.', column_name, '
                                                JOIN eav_attribute AS ea ON ed.attribute_id = ea.attribute_id
                                                JOIN eav_entity_type AS eet ON ea.entity_type_id = eet.entity_type_id
                                                WHERE ea.attribute_code = ''price''
                                                AND eet.entity_type_code = ''catalog_product''
                                                AND e.entity_id = ce.entity_id
                                                LIMIT 1
                                            ) as price, ce.type_id, ce.attribute_set_id,
                                            (
                                                SELECT ei.value
                                                FROM catalog_product_entity AS e
                                                JOIN catalog_product_entity_int AS ei ON e.entity_id = ei.', column_name ,'
                                                JOIN eav_attribute AS ea ON ei.attribute_id = ea.attribute_id
                                                JOIN eav_entity_type AS eet ON ea.entity_type_id = eet.entity_type_id
                                                WHERE ea.attribute_code = ''status''
                                                AND eet.entity_type_code = ''catalog_product''
                                                AND e.entity_id = ce.entity_id
                                                LIMIT 1
                                            ) as status,'
                                    )
                                ),
                                ' WHERE
                                    ea.attribute_code = "name" ',
                                IF(
                                    websiteId > -1,
                                    CONCAT(
                                        ' AND (SELECT count(*) FROM catalog_product_website ',
                                        'WHERE product_id = ce.entity_id AND website_id = ',
                                        websiteId,') > 0'
                                        ),
                                    ''
                                ),
                                ' ORDER BY
                                    ce.sku',
                                IF(
                                    page > -1,
                                    CONCAT(' LIMIT ', page, ', ', pageSize),
                                    ''
                                ),
                                ';'
                            );
                        IF isSQLOnly > 0 THEN
                            SELECT TRIM(stmt) AS 'SQL query';
                        ELSE
                            EXECUTE IMMEDIATE stmt;
                        END IF;

                    END;
                END IF;
            END;
    END CASE;
END$$

