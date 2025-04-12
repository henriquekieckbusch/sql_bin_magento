DELIMITER $$

DROP PROCEDURE IF EXISTS bin_magento_call_customers_list$$

CREATE PROCEDURE `bin_magento_call_customers_list`(IN cmd VARCHAR(255))
    COMMENT 'Listing all the Customers, use `--help` to see additional commands'
BEGIN
    DECLARE isFull BOOLEAN DEFAULT FALSE;
    DECLARE isSQLOnly BOOLEAN DEFAULT FALSE;
    DECLARE pageSize INT DEFAULT 12;
    DECLARE page INT DEFAULT 1;
    DECLARE websiteId INT DEFAULT -1;
    DECLARE emailFilter VARCHAR(255) DEFAULT NULL;
    DECLARE websiteCodeTemp VARCHAR(255);
    DECLARE customerCount INT DEFAULT 0;
    DECLARE selectedCustomerId INT DEFAULT NULL;
    DECLARE offsetVal INT DEFAULT 0;
    DECLARE limitOffset INT DEFAULT 0;
    DROP TEMPORARY TABLE IF EXISTS temp_results;
    CREATE TEMPORARY TABLE temp_results (
                                            Details TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    );

    main_block: BEGIN
        SET isFull = LOCATE('--full', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--full', ''));

        SET isSQLOnly = LOCATE('--sql', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--sql', ''));

        IF LOCATE('--website=', cmd) > 0 THEN
            SET websiteCodeTemp = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--website=', -1), ' ', 1));
            SET cmd = TRIM(REPLACE(cmd, CONCAT('--website=', websiteCodeTemp), ''));
            SELECT website_id INTO websiteId
            FROM store_website
            WHERE code = websiteCodeTemp
            LIMIT 1;
            IF websiteId < 0 THEN
                INSERT INTO temp_results (Details)
                VALUES (CONCAT('Ooops! I didn\'t find any website with the code: `', websiteCodeTemp, '`'));
                SELECT Details FROM temp_results;
                DROP TEMPORARY TABLE temp_results;
                LEAVE main_block;
            END IF;
        END IF;

        IF LOCATE('--pageSize=', cmd) > 0 THEN
            SET pageSize = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--pageSize=', -1), ' ', 1) AS SIGNED);
            SET cmd = TRIM(REPLACE(cmd, CONCAT('--pageSize=', pageSize), ''));
        END IF;

        IF LOCATE('--page=', cmd) > 0 THEN
            SET page = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--page=', -1), ' ', 1) AS SIGNED);
            SET cmd = TRIM(REPLACE(cmd, CONCAT('--page=', page), ''));
        ELSE
            SET page = 1;
        END IF;

        SET cmd = TRIM(cmd);
        IF cmd != '' AND cmd != '--help' THEN
            SET emailFilter = cmd;
        END IF;

        CASE cmd
            WHEN '--help' THEN
                BEGIN
                    SELECT ':::' AS 'Details' UNION ALL
                    SELECT '::: Use commands like:' AS 'Details' UNION ALL
                    SELECT ':::' AS 'Details' UNION ALL
                    SELECT '`customers:list --help`                           - ℹ️ To see this help' AS 'Details' UNION ALL
                    SELECT '`customers:list`                                  - ℹ️ [slow command] It will list id, website_code, email, created_at, is_active, firstname, lastname of the customers' AS 'Details' UNION ALL
                    SELECT '`customers:list <full email>`                     - ℹ️ It will give full details + Addresses of this customer' AS 'Details' UNION ALL
                    SELECT '`<command> --full`                                - ℹ️ [slow command] It will list all the attributes of the customers' AS 'Details' UNION ALL
                    SELECT '`<command> --website=<website_code>`              - ℹ️ It will filter by website' AS 'Details' UNION ALL
                    SELECT '`<command> --pageSize=<number>`                   - ℹ️ To set the number of items per page, default is 12' AS 'Details' UNION ALL
                    SELECT '`<command> --page=<number>`                       - ℹ️ To get just specific page (no space around `=`)' AS 'Details' UNION ALL
                    SELECT '`<command> --sql`                                 - ℹ️ It will render the SQL command used' AS 'Details';
                END;
            ELSE
                BEGIN
                    IF emailFilter IS NOT NULL THEN
                        SELECT COUNT(*) INTO customerCount
                        FROM customer_entity
                        WHERE email = emailFilter;

                        IF customerCount = 0 THEN
                            INSERT INTO temp_results (Details)
                            VALUES (CONCAT('Ooops! I didn\'t find any customer with the email: `', emailFilter, '`'));
                            SELECT Details FROM temp_results;
                            DROP TEMPORARY TABLE temp_results;
                            LEAVE main_block;
                        END IF;

                        IF page < 1 THEN
                            SET page = 1;
                        END IF;

                        DROP TEMPORARY TABLE IF EXISTS temp_customer_ids;
                        CREATE TEMPORARY TABLE temp_customer_ids (
                                                                     entity_id INT PRIMARY KEY
                        );
                        INSERT INTO temp_customer_ids (entity_id)
                        SELECT entity_id
                        FROM customer_entity
                        WHERE email = emailFilter
                        ORDER BY entity_id ASC;

                        SET offsetVal = page - 1;

                        SELECT entity_id INTO selectedCustomerId
                        FROM temp_customer_ids
                        LIMIT 1 OFFSET offsetVal;

                        IF selectedCustomerId IS NULL THEN
                            INSERT INTO temp_results (Details)
                            VALUES (CONCAT('No customer found for page ', page, ' with email `', emailFilter, '`. There are only ', customerCount, ' customers.'));
                            SELECT Details FROM temp_results;
                            DROP TEMPORARY TABLE temp_results;
                            DROP TEMPORARY TABLE temp_customer_ids;
                            LEAVE main_block;
                        END IF;

                        DROP TEMPORARY TABLE temp_customer_ids;

                        IF customerCount > 1 THEN
                            INSERT INTO temp_results (Details)
                            VALUES (CONCAT('I found ', customerCount, ' customers with the email `', emailFilter, '`. Showing page: ', page, '. Use --page=<number> to see others.'));
                        END IF;

                        INSERT INTO temp_results (Details)
                        SELECT CONCAT(
                                       'entity_id:', ce.entity_id, '\n',
                                       'website_id:', IFNULL(ce.website_id, ''), '\n',
                                       'email:', ce.email, '\n',
                                       'created_at:', IFNULL(ce.created_at, ''), '\n',
                                       'updated_at:', IFNULL(ce.updated_at, ''), '\n',
                                       'is_active:', IFNULL(ce.is_active, ''), '\n',
                                       'firstname:', IFNULL(ce.firstname, ''), '\n',
                                       'lastname:', IFNULL(ce.lastname, ''), '\n',
                                       'store_id:', IFNULL(ce.store_id, ''), '\n',
                                       'group_id:', IFNULL(ce.group_id, ''), '\n',
                                       'default_billing:', IFNULL(ce.default_billing, ''), '\n',
                                       'default_shipping:', IFNULL(ce.default_shipping, ''), '\n',
                                       'created_in:', IFNULL(ce.created_in, ''), '\n',
                                       'disable_auto_group_change:', IFNULL(ce.disable_auto_group_change, ''), '\n',
                                       IFNULL((SELECT GROUP_CONCAT(CONCAT(ea.attribute_code, ':', ev.value) SEPARATOR '\n')
                                               FROM eav_attribute ea
                                                        LEFT JOIN customer_entity_varchar ev ON ea.attribute_id = ev.attribute_id AND ev.entity_id = ce.entity_id
                                               WHERE ea.entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')
                                                 AND ev.value IS NOT NULL), ''),
                                       '\n',
                                       IFNULL((SELECT GROUP_CONCAT(CONCAT(ea.attribute_code, ':', ev.value) SEPARATOR '\n')
                                               FROM eav_attribute ea
                                                        LEFT JOIN customer_entity_int ev ON ea.attribute_id = ev.attribute_id AND ev.entity_id = ce.entity_id
                                               WHERE ea.entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')
                                                 AND ev.value IS NOT NULL), ''),
                                       '\n',
                                       IFNULL((SELECT GROUP_CONCAT(CONCAT(ea.attribute_code, ':', ev.value) SEPARATOR '\n')
                                               FROM eav_attribute ea
                                                        LEFT JOIN customer_entity_datetime ev ON ea.attribute_id = ev.attribute_id AND ev.entity_id = ce.entity_id
                                               WHERE ea.entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')
                                                 AND ev.value IS NOT NULL), ''),
                                       '\n',
                                       IFNULL((SELECT GROUP_CONCAT(CONCAT(ea.attribute_code, ':', ev.value) SEPARATOR '\n')
                                               FROM eav_attribute ea
                                                        LEFT JOIN customer_entity_text ev ON ea.attribute_id = ev.attribute_id AND ev.entity_id = ce.entity_id
                                               WHERE ea.entity_type_id = (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')
                                                 AND ev.value IS NOT NULL), '')
                               )
                        FROM customer_entity ce
                        WHERE ce.entity_id = selectedCustomerId;

                        INSERT INTO temp_results (Details)
                        SELECT IFNULL(CONCAT(
                                              'Default Shipping Address:\n',
                                              'firstname:', IFNULL(ca.firstname, ''), '\n',
                                              'lastname:', IFNULL(ca.lastname, ''), '\n',
                                              'street:', IFNULL(ca.street, ''), '\n',
                                              'city:', IFNULL(ca.city, ''), '\n',
                                              'region:', IFNULL(ca.region, ''), '\n',
                                              'postcode:', IFNULL(ca.postcode, ''), '\n',
                                              'country_id:', IFNULL(ca.country_id, ''), '\n',
                                              'telephone:', IFNULL(ca.telephone, ''), '\n',
                                              'company:', IFNULL(ca.company, '')
                                      ), 'No default shipping address')
                        FROM customer_entity ce
                                 LEFT JOIN customer_address_entity ca ON ce.default_shipping = ca.entity_id
                        WHERE ce.entity_id = selectedCustomerId;

                        INSERT INTO temp_results (Details)
                        SELECT IFNULL(CONCAT(
                                              'Default Billing Address:\n',
                                              'firstname:', IFNULL(ca.firstname, ''), '\n',
                                              'lastname:', IFNULL(ca.lastname, ''), '\n',
                                              'street:', IFNULL(ca.street, ''), '\n',
                                              'city:', IFNULL(ca.city, ''), '\n',
                                              'region:', IFNULL(ca.region, ''), '\n',
                                              'postcode:', IFNULL(ca.postcode, ''), '\n',
                                              'country_id:', IFNULL(ca.country_id, ''), '\n',
                                              'telephone:', IFNULL(ca.telephone, ''), '\n',
                                              'company:', IFNULL(ca.company, '')
                                      ), 'No default billing address')
                        FROM customer_entity ce
                                 LEFT JOIN customer_address_entity ca ON ce.default_billing = ca.entity_id
                        WHERE ce.entity_id = selectedCustomerId;

                        INSERT INTO temp_results (Details)
                        SELECT IFNULL(CONCAT(
                                              'Additional Address:\n',
                                              'firstname:', IFNULL(ca.firstname, ''), '\n',
                                              'lastname:', IFNULL(ca.lastname, ''), '\n',
                                              'street:', IFNULL(ca.street, ''), '\n',
                                              'city:', IFNULL(ca.city, ''), '\n',
                                              'region:', IFNULL(ca.region, ''), '\n',
                                              'postcode:', IFNULL(ca.postcode, ''), '\n',
                                              'country_id:', IFNULL(ca.country_id, ''), '\n',
                                              'telephone:', IFNULL(ca.telephone, ''), '\n',
                                              'company:', IFNULL(ca.company, '')
                                      ), 'No additional address')
                        FROM customer_entity ce
                                 LEFT JOIN customer_address_entity ca ON ce.entity_id = ca.parent_id
                        WHERE ce.entity_id = selectedCustomerId
                          AND ca.entity_id NOT IN (IFNULL(ce.default_shipping, 0), IFNULL(ce.default_billing, 0))
                        LIMIT 1;

                        IF isSQLOnly THEN
                            INSERT INTO temp_results (Details)
                            VALUES ('This version does not support --sql with dynamic query generation for email filter mode. Remove --sql to see results.');
                            SELECT Details FROM temp_results;
                        ELSE
                            SELECT Details FROM temp_results;
                        END IF;
                        DROP TEMPORARY TABLE temp_results;
                    ELSE
                        SET limitOffset = (page - 1) * pageSize;

                        IF isFull THEN
                            BEGIN
                                DECLARE attribute_code VARCHAR(255);
                                DECLARE attribute_id INT;
                                DECLARE attribute_type VARCHAR(255);
                                DECLARE done INT DEFAULT 0;
                                DECLARE sql_query TEXT DEFAULT 'SELECT ce.entity_id AS id, sw.code AS website_code, ce.email, ce.created_at, ce.is_active';

                                DECLARE cur CURSOR FOR
                                    SELECT ea.attribute_code, ea.attribute_id, ea.backend_type
                                    FROM eav_attribute AS ea
                                             JOIN eav_entity_type AS eet ON ea.entity_type_id = eet.entity_type_id
                                    WHERE eet.entity_type_code = 'customer';
                                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

                                DROP TEMPORARY TABLE IF EXISTS temp_full_results;
                                CREATE TEMPORARY TABLE temp_full_results (
                                                                             id INT,
                                                                             website_code VARCHAR(255),
                                                                             email VARCHAR(255),
                                                                             created_at DATETIME,
                                                                             is_active INT
                                );

                                INSERT INTO temp_full_results (id, website_code, email, created_at, is_active)
                                SELECT ce.entity_id, sw.code, ce.email, ce.created_at, ce.is_active
                                FROM customer_entity ce
                                         LEFT JOIN store_website sw ON ce.website_id = sw.website_id
                                WHERE (websiteId = -1 OR ce.website_id = websiteId)
                                LIMIT limitOffset, pageSize;

                                OPEN cur;
                                read_loop: LOOP
                                    FETCH cur INTO attribute_code, attribute_id, attribute_type;
                                    IF done THEN
                                        LEAVE read_loop;
                                    END IF;

                                    IF attribute_code IN ('entity_id', 'website_id', 'email', 'created_at', 'is_active') THEN
                                        ITERATE read_loop;
                                    END IF;

                                    SET @alter_query = CONCAT(
                                            'ALTER TABLE temp_full_results ADD COLUMN `', attribute_code, '` ',
                                            CASE
                                                WHEN attribute_type = 'static' AND attribute_code IN ('updated_at', 'dob', 'first_failure', 'lock_expires', 'rp_token_created_at') THEN 'DATETIME'
                                                WHEN attribute_type = 'static' AND attribute_code IN ('store_id', 'group_id', 'default_billing', 'default_shipping', 'disable_auto_group_change', 'failures_num') THEN 'INT'
                                                WHEN attribute_type = 'varchar' THEN 'VARCHAR(255)'
                                                WHEN attribute_type = 'int' THEN 'INT'
                                                WHEN attribute_type = 'datetime' THEN 'DATETIME'
                                                WHEN attribute_type = 'text' THEN 'TEXT'
                                                ELSE 'VARCHAR(255)'
                                                END
                                                       );
                                    PREPARE alter_stmt FROM @alter_query;
                                    EXECUTE alter_stmt;
                                    DEALLOCATE PREPARE alter_stmt;

                                    IF attribute_type = 'static' THEN
                                        IF EXISTS (
                                            SELECT 1
                                            FROM INFORMATION_SCHEMA.COLUMNS
                                            WHERE TABLE_SCHEMA = DATABASE()
                                              AND TABLE_NAME = 'customer_entity'
                                              AND COLUMN_NAME = attribute_code
                                        ) THEN
                                            SET sql_query = CONCAT(
                                                    sql_query,
                                                    ', ce.', attribute_code, ' AS `', attribute_code, '`'
                                                            );
                                            SET @update_query = CONCAT(
                                                    'UPDATE temp_full_results tfr ',
                                                    'JOIN customer_entity ce ON tfr.id = ce.entity_id ',
                                                    'SET tfr.`', attribute_code, '` = ce.`', attribute_code, '`'
                                                                );
                                            PREPARE update_stmt FROM @update_query;
                                            EXECUTE update_stmt;
                                            DEALLOCATE PREPARE update_stmt;
                                        END IF;
                                    ELSE
                                        SET sql_query = CONCAT(
                                                sql_query,
                                                ', (SELECT value FROM customer_entity_', attribute_type,
                                                ' WHERE entity_id = ce.entity_id AND attribute_id = ', attribute_id,
                                                ' LIMIT 1) AS `', attribute_code, '`'
                                                        );
                                        SET @update_query = CONCAT(
                                                'UPDATE temp_full_results tfr ',
                                                'LEFT JOIN customer_entity_', attribute_type, ' ev ',
                                                'ON tfr.id = ev.entity_id AND ev.attribute_id = ', attribute_id, ' ',
                                                'SET tfr.`', attribute_code, '` = ev.value'
                                                            );
                                        PREPARE update_stmt FROM @update_query;
                                        EXECUTE update_stmt;
                                        DEALLOCATE PREPARE update_stmt;
                                    END IF;
                                END LOOP;
                                CLOSE cur;

                                SET sql_query = CONCAT(
                                        sql_query,
                                        ' FROM customer_entity ce ',
                                        'LEFT JOIN store_website sw ON ce.website_id = sw.website_id ',
                                        IF(websiteId > -1, CONCAT('WHERE ce.website_id = ', websiteId), ''),
                                        ' LIMIT ', limitOffset, ', ', pageSize
                                                );

                                IF isSQLOnly THEN
                                    INSERT INTO temp_results (Details)
                                    VALUES (sql_query);
                                    SELECT Details FROM temp_results;
                                    DROP TEMPORARY TABLE temp_results;
                                ELSE
                                    SELECT * FROM temp_full_results;
                                    DROP TEMPORARY TABLE temp_full_results;
                                END IF;
                            END;
                        ELSE
                            IF isSQLOnly THEN
                                SET @sql = CONCAT(
                                        'SELECT ce.entity_id AS id, sw.code AS website_code, ce.email, ce.created_at, ce.is_active, ',
                                        'ce.firstname AS firstname, ce.lastname AS lastname ',
                                        'FROM customer_entity ce ',
                                        'LEFT JOIN store_website sw ON ce.website_id = sw.website_id ',
                                        IF(websiteId > -1, CONCAT('WHERE ce.website_id = ', websiteId), ''),
                                        ' LIMIT ', limitOffset, ', ', pageSize
                                           );
                                INSERT INTO temp_results (Details)
                                VALUES (@sql);
                                SELECT Details FROM temp_results;
                                DROP TEMPORARY TABLE temp_results;
                            ELSE
                                SELECT ce.entity_id AS id, sw.code AS website_code, ce.email, ce.created_at, ce.is_active,
                                       ce.firstname AS firstname, ce.lastname AS lastname
                                FROM customer_entity ce
                                         LEFT JOIN store_website sw ON ce.website_id = sw.website_id
                                WHERE (websiteId = -1 OR ce.website_id = websiteId)
                                LIMIT limitOffset, pageSize;
                            END IF;
                        END IF;
                    END IF;
                END;
            END CASE;
    END main_block;
END$$
