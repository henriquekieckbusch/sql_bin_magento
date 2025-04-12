DELIMITER $$

DROP PROCEDURE IF EXISTS bin_magento$$

CREATE PROCEDURE `bin_magento`(IN cmd VARCHAR(255))
BEGIN
    DECLARE procedure_name VARCHAR(255);
    DECLARE argument VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SELECT 'An error occurred while executing the procedure' AS 'Error';
        END;

    IF cmd IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Command cannot be NULL';
    END IF;

    IF TRIM(cmd) = '' OR TRIM(cmd) = '--help' THEN
        BEGIN
            SELECT ':: bin_magento by Henrique Kieckbusch ::' AS `Message`
            UNION ALL
            SELECT CONCAT(':: Available commands - Use `--help` with any command for more details ::',
                          ' Example: `catalog:attributes:list --help`') AS `Message`
            UNION ALL
            SELECT CONCAT(
                           REPLACE(
                                   SUBSTRING(routine_name, LENGTH('bin_magento_call_') + 1),
                                   '_', ':'
                           ),
                           ' - ℹ️  ',
                           routine_comment
                   ) AS `Available Commands`
            FROM information_schema.routines
            WHERE routine_schema = DATABASE()
              AND routine_name LIKE 'bin_magento_call_%'
            ORDER BY 1;
        END;
    ELSE
        BEGIN
            SET procedure_name = CONCAT(
                    'bin_magento_call_',
                    REPLACE(TRIM(SUBSTRING_INDEX(cmd, ' ', 1)), ':', '_')
                                 );
            SET argument = TRIM(SUBSTR(cmd, INSTR(cmd, ' ') + 1));
            IF argument = TRIM(cmd) THEN
                SET argument = '';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM information_schema.routines
                WHERE routine_schema = DATABASE()
                  AND routine_name = procedure_name
            ) THEN
                SET @full_command = CONCAT('CALL ', procedure_name, '(?)');
                SET @cmd_param = argument;
                PREPARE stmt FROM @full_command;
                EXECUTE stmt USING @cmd_param;
                DEALLOCATE PREPARE stmt;
            ELSE
                SELECT CONCAT(
                               'Command `',
                               SUBSTRING_INDEX(cmd, ' ', 1),
                               '` not found. Try `--help` for available commands'
                       ) AS `Error`
                UNION ALL
                SELECT CONCAT(
                               'Similar commands: ',
                               IFNULL(
                                       (
                                           SELECT GROUP_CONCAT(
                                                          CONCAT(
                                                                  '`',
                                                                  REPLACE(
                                                                          SUBSTRING(routine_name, LENGTH('bin_magento_call_') + 1),
                                                                          '_', ':'
                                                                  ),
                                                                  '`'
                                                          ) SEPARATOR ', '
                                                  )
                                           FROM information_schema.routines
                                           WHERE routine_schema = DATABASE()
                                             AND routine_name LIKE 'bin_magento_call_%'
                                             AND routine_name LIKE CONCAT('%', REPLACE(SUBSTRING_INDEX(cmd, ' ', 1), ':', '_'), '%')
                                       ),
                                       'None found'
                               )
                       ) AS `Suggestions`;
            END IF;
        END;
    END IF;
END$$
delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_admin_user_list$$

CREATE PROCEDURE `bin_magento_call_admin_user_list`(IN cmd VARCHAR(255))
    COMMENT 'List all the Admin panel users'
BEGIN
    DECLARE showFull SMALLINT;
    SET showFull = LOCATE('--full', cmd) > 0;
    SET cmd = REPLACE(cmd, '--full', '');

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`admin:user:list --help`   - ℹ️ To see this help' AS 'help'
                    UNION ALL
                SELECT '`admin:user:list`          - ℹ️ It list all the admin users' AS 'help'
                UNION ALL
                SELECT '`admin:user:list --full`   - ℹ️ It returns the full admin_user table content' AS 'help';
            END;
        ELSE
            BEGIN
                IF showFull THEN
                    SELECT * FROM admin_user;
                ELSE
                    SELECT
                        user_id,
                        username,
                        email,
                        IF(is_active = 1, 'Yes', 'No') AS Active,
                        if(lock_expires IS NOT NULL, 'Locked', '') AS Status,
                        modified
                    FROM
                        admin_user
                    ORDER BY
                        username;
                END IF;
            END;
    END CASE;

END$$

delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_admin_user_lock$$

CREATE PROCEDURE `bin_magento_call_admin_user_lock`(IN cmd VARCHAR(255))
    COMMENT 'Lock an admin user'
BEGIN
    DECLARE userId VARCHAR(255);
    DECLARE forAll SMALLINT;
    SET forAll = LOCATE('--all', cmd) > 0;
    SET cmd = TRIM(REPLACE(cmd, '--all', ''));

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`admin:user:lock --help`    - ℹ️ To see this help" AS \'help\''
                    UNION ALL
                SELECT '`admin:user:lock <username>`- ℹ️ It will lock the admin user by username'
                           AS 'help'
                    UNION ALL
                SELECT '`admin:user:lock <email>`   - ℹ️ It will lock the admin user by email'
                           AS 'help'
                    UNION ALL
                SELECT '`admin:user:lock --all`     - ℹ️ It will lock all admin users'
                           AS 'help';
            END;
        ELSE
            BEGIN
                IF forAll > 0 THEN
                    UPDATE
                        admin_user
                    SET
                        failures_num = 99,
                        first_failure = NOW(),
                        lock_expires = DATE_ADD(NOW(), INTERVAL 10 YEAR)
                    WHERE 1;
                    SELECT 'Done! Please use `call bin_magento(\'admin:user:list\');` to check if it worked fine.'
                        AS Done;
                ELSE
                    SELECT user_id INTO userId FROM admin_user WHERE email = cmd OR username = cmd;
                    IF ISNULL(userId) THEN
                        SELECT CONCAT('I didn\'t find any admin user with the `email` or `username`: `', cmd, '`')
                            AS 'Ooops!';
                    ELSE
                        UPDATE
                            admin_user
                        SET
                            failures_num = 99,
                            first_failure = NOW(),
                            lock_expires = DATE_ADD(NOW(), INTERVAL 10 YEAR)
                        WHERE user_id = userId;
                        SELECT 'Done! Please use `call bin_magento(\'admin:user:list\');` to check if it worked fine.'
                                   AS Done;
                    END IF;
                END IF;
            END;
        END CASE;

END$$

delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_admin_user_unlock$$

CREATE PROCEDURE `bin_magento_call_admin_user_unlock`(IN cmd VARCHAR(255))
    COMMENT 'Unlock an admin user'
BEGIN
    DECLARE userId VARCHAR(255);
    DECLARE forAll SMALLINT;
    SET forAll = LOCATE('--all', cmd) > 0;
    SET cmd = TRIM(REPLACE(cmd, '--all', ''));

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`admin:user:unlock --help`   - ℹ️ To see this help" AS \'help\''
                    UNION ALL
                SELECT '`admin:user:unlock <username>`             - ℹ️ It will unlock the admin user by username'
                    AS 'help'
                    UNION ALL
                SELECT '`admin:user:unlock <email>`             - ℹ️ It will unlock the admin user by email'
                    AS 'help'
                    UNION ALL
                SELECT '`admin:user:unlock --all`             - ℹ️ It will unlock all admin users'
                    AS 'help';
            END;
        ELSE
            BEGIN
                IF forAll > 0 THEN
                    UPDATE
                        admin_user
                    SET
                        failures_num = 0,
                        first_failure = NULL,
                        lock_expires = NULL
                    WHERE 1;
                    SELECT 'Done! Please use `call bin_magento(\'admin:user:list\');` to check if it worked fine.'
                               AS Done;
                ELSE
                    SELECT user_id INTO userId FROM admin_user WHERE email = cmd OR username = cmd;
                    IF ISNULL(userId) THEN
                        SELECT CONCAT('I didn\'t find any admin user with the `email` or `username`: `', cmd, '`')
                                   AS 'Ooops!';
                    ELSE
                        UPDATE
                            admin_user
                        SET
                            failures_num = 0,
                            first_failure = NULL,
                            lock_expires = NULL
                        WHERE user_id = userId;
                        SELECT 'Done! Please use `call bin_magento(\'admin:user:list\');` to check if it worked fine.'
                                   AS Done;
                    END IF;
                END IF;
            END;
        END CASE;

END$$

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

DELIMITER $$

DROP PROCEDURE IF EXISTS bin_magento_call_config_show$$

CREATE PROCEDURE `bin_magento_call_config_show`(IN cmd VARCHAR(255))
    COMMENT 'Show the Magento Config'
BEGIN
    DECLARE website_id_filter INT DEFAULT NULL;
    DECLARE store_id_filter INT DEFAULT NULL;
    DECLARE website_code_temp VARCHAR(255);
    DECLARE store_code_temp VARCHAR(255);

    main_block: BEGIN
        SET @isFull = LOCATE('--full', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--full', ''));

        SET @isDefault = LOCATE('--default', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--default', ''));

        IF LOCATE('--website=', cmd) > 0 THEN
            SET website_code_temp = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--website=', -1), ' ', 1));
            SET cmd = TRIM(REPLACE(cmd, CONCAT('--website=', website_code_temp), ''));
            SELECT website_id INTO website_id_filter
            FROM store_website
            WHERE code = website_code_temp
            LIMIT 1;
            IF website_id_filter IS NULL THEN
                SELECT CONCAT('Ooops! I didn\'t find any website with the code: `', website_code_temp, '`') AS 'Ooops!';
                LEAVE main_block;
            END IF;
        END IF;

        IF LOCATE('--store=', cmd) > 0 THEN
            SET store_code_temp = TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(cmd, '--store=', -1), ' ', 1));
            SET cmd = TRIM(REPLACE(cmd, CONCAT('--store=', store_code_temp), ''));
            SELECT store_id INTO store_id_filter
            FROM store
            WHERE code = store_code_temp
            LIMIT 1;
            IF store_id_filter IS NULL THEN
                SELECT CONCAT('Ooops! I didn\'t find any store with the code: `', store_code_temp, '`') AS 'Ooops!';
                LEAVE main_block;
            END IF;
        END IF;

        CASE cmd
            WHEN '--help' THEN
                BEGIN
                    SELECT ':::' AS 'help'
                    UNION ALL
                    SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                    SELECT ':::' AS 'help'
                    UNION ALL
                    SELECT '`config:show --help`                     - ℹ️ To see this help' AS 'help'
                    UNION ALL
                    SELECT '`config:show`                            - ℹ️ It lists all the Magento configs' AS 'help'
                    UNION ALL
                    SELECT '`config:show <config or partial config>` - ℹ️ It lists the Magento configs that contains your <config> text' AS 'help'
                    UNION ALL
                    SELECT '`<command> --website=<website_code>`     - ℹ️ It will filter by the website_code you put there' AS 'help'
                    UNION ALL
                    SELECT '`<command> --store=<store_code>`         - ℹ️ It will filter by store_code you put there' AS 'help'
                    UNION ALL
                    SELECT '`<command> --default`                    - ℹ️ It will filter just the default configs' AS 'help'
                    UNION ALL
                    SELECT '`<command> --full`                       - ℹ️ It will show the full `value` content' AS 'help';
                END;
            ELSE
                BEGIN
                    CREATE TEMPORARY TABLE IF NOT EXISTS matching_configs AS
                    SELECT path, config_id, scope, value, scope_id
                    FROM core_config_data
                    WHERE
                        ((website_id_filter IS NULL AND store_id_filter IS NULL AND @isDefault = 0)
                            OR (website_id_filter IS NOT NULL AND scope = 'websites' AND scope_id = website_id_filter)
                            OR (store_id_filter IS NOT NULL AND scope = 'stores' AND scope_id = store_id_filter)
                            OR (@isDefault = 1 AND scope = 'default'))
                      AND (cmd = '' OR path LIKE CONCAT('%', cmd, '%'))
                    ORDER BY path, scope;

                    CREATE TEMPORARY TABLE IF NOT EXISTS hierarchy (
                                                                       id INT AUTO_INCREMENT PRIMARY KEY,
                                                                       path VARCHAR(255) NOT NULL,
                                                                       display_path VARCHAR(255) NOT NULL,
                                                                       full_path VARCHAR(255) NOT NULL,
                                                                       level INT NOT NULL,
                                                                       config_id INT,
                                                                       scope VARCHAR(10),
                                                                       value TEXT,
                                                                       scope_id INT,
                                                                       `where` VARCHAR(255)
                    );

                    INSERT INTO hierarchy (path, display_path, full_path, level, config_id, scope, value, scope_id)
                    SELECT
                        SUBSTRING_INDEX(path, '/', 1) AS path,
                        SUBSTRING_INDEX(path, '/', 1) AS display_path,
                        SUBSTRING_INDEX(path, '/', 1) AS full_path,
                        0 AS level,
                        NULL AS config_id,
                        NULL AS scope,
                        NULL AS value,
                        NULL AS scope_id
                    FROM matching_configs
                    GROUP BY SUBSTRING_INDEX(path, '/', 1);

                    INSERT INTO hierarchy (path, display_path, full_path, level, config_id, scope, value, scope_id)
                    SELECT
                        SUBSTRING_INDEX(SUBSTRING_INDEX(path, '/', 2), '/', -1) AS path,
                        CONCAT('  / ', SUBSTRING_INDEX(SUBSTRING_INDEX(path, '/', 2), '/', -1)) AS display_path,
                        SUBSTRING_INDEX(path, '/', 2) AS full_path,
                        1 AS level,
                        NULL AS config_id,
                        NULL AS scope,
                        NULL AS value,
                        NULL AS scope_id
                    FROM matching_configs
                    WHERE LOCATE('/', path) > 0
                    GROUP BY SUBSTRING_INDEX(path, '/', 2);

                    INSERT INTO hierarchy (path, display_path, full_path, level, config_id, scope, value, scope_id)
                    SELECT
                        SUBSTRING_INDEX(path, '/', -1) AS path,
                        CONCAT('      / ', SUBSTRING_INDEX(path, '/', -1)) AS display_path,
                        path AS full_path,
                        2 AS level,
                        config_id,
                        scope,
                        value,
                        scope_id
                    FROM matching_configs
                    WHERE LOCATE('/', path, LOCATE('/', path) + 1) > 0;

                    UPDATE hierarchy
                    SET `where` = CASE
                                      WHEN scope = 'default' THEN '*'
                                      WHEN scope = 'stores' THEN (
                                          SELECT GROUP_CONCAT(s.code)
                                          FROM store s
                                          WHERE s.store_id = scope_id
                                      )
                                      WHEN scope = 'websites' THEN (
                                          SELECT GROUP_CONCAT(w.code)
                                          FROM store_website w
                                          WHERE w.website_id = scope_id
                                      )
                                      ELSE ''
                        END
                    WHERE level = 2;
                    SELECT
                        display_path AS path,
                        IFNULL(scope, '') AS scope,
                        IFNULL(`where`, '') AS `where`,
                        IF(
                                @isFull,
                                value,
                                REPLACE(REPLACE(REPLACE(LEFT(IFNULL(value, ''), 60), '\r', ''), '\n', ''), '\r\n', '')
                        ) AS value
                    FROM hierarchy
                    ORDER BY full_path, level;

                    DROP TEMPORARY TABLE IF EXISTS matching_configs;
                    DROP TEMPORARY TABLE IF EXISTS hierarchy;
                END;
            END CASE;
    END main_block;
END$$
DELIMITER $$

DROP PROCEDURE IF EXISTS bin_magento_call_cron_list$$

CREATE PROCEDURE `bin_magento_call_cron_list`(IN cmd VARCHAR(255))
BEGIN
    DECLARE isFull BOOLEAN DEFAULT FALSE;
    DECLARE filterDone BOOLEAN DEFAULT FALSE;
    DECLARE filterQueue BOOLEAN DEFAULT FALSE;
    DECLARE filterError BOOLEAN DEFAULT FALSE;
    DECLARE jobCodeFilter VARCHAR(255) DEFAULT NULL;

    main_block: BEGIN
        SET isFull = LOCATE('--full', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--full', ''));

        SET filterDone = LOCATE('--done', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--done', ''));

        SET filterQueue = LOCATE('--queue', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--queue', ''));

        SET filterError = LOCATE('--error', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--error', ''));

        SET cmd = TRIM(cmd);
        IF cmd != '' AND cmd != '--help' THEN
            SET jobCodeFilter = cmd;
        END IF;

        CASE cmd
            WHEN '--help' THEN
                BEGIN
                    SELECT ':::' AS 'help'
                    UNION ALL
                    SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                    SELECT ':::' AS 'help'
                    UNION ALL
                    SELECT '`cron:list --help`   - ℹ️ To see this help' AS 'help'
                    UNION ALL
                    SELECT '`cron:list`          - ℹ️ It list all the Magento crons (Limit of 3 by cron)' AS 'help'
                    UNION ALL
                    SELECT '`cron:list <partial job code name>` - ℹ️ Filter by job code' AS 'help'
                    UNION ALL
                    SELECT '`<command> --full`   - ℹ️ Remove the limit' AS 'help'
                    UNION ALL
                    SELECT '`<command> --done`   - ℹ️ List the executed ones' AS 'help'
                    UNION ALL
                    SELECT '`<command> --queue`  - ℹ️ List the scheduled ones' AS 'help'
                    UNION ALL
                    SELECT '`<command> --error`  - ℹ️ List the error/missed ones' AS 'help';
                END;
            ELSE
                BEGIN
                    CREATE TEMPORARY TABLE IF NOT EXISTS temp_cron (
                                                                       `job_code` VARCHAR(255),
                                                                       `status` VARCHAR(50),
                                                                       `created_at` DATETIME,
                                                                       `scheduled_at` DATETIME,
                                                                       `executed_at` DATETIME,
                                                                       `finished_at` DATETIME,
                                                                       `row_num` INT
                    );

                    INSERT INTO temp_cron
                    SELECT
                        job_code,
                        status,
                        created_at,
                        scheduled_at,
                        executed_at,
                        finished_at,
                        ROW_NUMBER() OVER (PARTITION BY job_code ORDER BY created_at DESC) AS row_num
                    FROM cron_schedule
                    WHERE
                        (jobCodeFilter IS NULL OR job_code LIKE CONCAT('%', jobCodeFilter, '%'))
                      AND (
                        (filterDone = FALSE AND filterQueue = FALSE AND filterError = FALSE)
                            OR (filterDone = TRUE AND status = 'success')
                            OR (filterQueue = TRUE AND status = 'pending')
                            OR (filterError = TRUE AND status IN ('error', 'missed'))
                        );

                    SELECT
                        CASE
                            WHEN t.level = 0 THEN CONCAT('- ', t.job_code)
                            ELSE
                                CASE CAST(t.status AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci
                                    WHEN 'success' THEN CAST('[✅]' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci
                                    WHEN 'pending' THEN CAST('[⏱️]' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci
                                    ELSE CAST('[❌]' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_general_ci
                                    END
                            END AS `Job Code`,
                        IF(t.level = 0, '', t.status) AS `Status`,
                        IF(t.level = 0, '', t.created_at) AS `Created`,
                        IF(t.level = 0, '', t.scheduled_at) AS `Scheduled`,
                        IF(t.level = 0, '', t.executed_at) AS `Executed`,
                        IF(t.level = 0, '', t.finished_at) AS `Finished`
                    FROM (
                             SELECT
                                 job_code,
                                 status,
                                 created_at,
                                 scheduled_at,
                                 executed_at,
                                 finished_at,
                                 0 AS level
                             FROM temp_cron
                             WHERE row_num = 1
                             UNION
                             SELECT
                                 job_code,
                                 status,
                                 created_at,
                                 scheduled_at,
                                 executed_at,
                                 finished_at,
                                 1 AS level
                             FROM temp_cron
                             WHERE (isFull = TRUE) OR (row_num <= 3)
                         ) t
                    ORDER BY t.job_code, t.level, t.created_at DESC;

                    DROP TEMPORARY TABLE IF EXISTS temp_cron;
                END;
            END CASE;
    END main_block;
END$$
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
delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_db_search$$

CREATE PROCEDURE `bin_magento_call_db_search`(IN cmd VARCHAR(255))
COMMENT 'Use as `db:seach "any text"` to search for the string inside ALL tables, please use Quotes "".'
BEGIN
    CASE cmd
        WHEN  '--help' THEN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`db:search --help`   - ℹ️ To see this help' AS 'help'
                    UNION ALL
                SELECT CONCAT('`db:search <text>`   ',
                       '- ℹ️ [slow] It will search for the text inside all tables') AS 'help';
        WHEN '' THEN
                SELECT CONCAT('Please use any text after the command to search for it. ',
                    'Or send `--help` to get the list of commands.') AS 'Ooops!';
        ELSE
            BEGIN
                DECLARE done INT DEFAULT 0;
                DECLARE result TEXT DEFAULT '';
                DECLARE sum INT DEFAULT 0;
                DECLARE tableName, columnName VARCHAR(255);
                DECLARE cur CURSOR FOR
                    SELECT table_name, column_name
                    FROM information_schema.columns
                    WHERE table_schema = DATABASE();
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
                SELECT 'Please wait, it can take a while...' AS 'Searching inside Magento database...';
                OPEN cur;
                myLoop: LOOP
                    FETCH cur INTO tableName, columnName;
                    IF done THEN
                        LEAVE myLoop;
                    END IF;
                    SET @sql = CONCAT(
                            'SELECT COUNT(*) INTO @count FROM `', tableName,
                            '` WHERE `', columnName, '` LIKE ', CONCAT('\'%', cmd, '%\'')
                        );
                    EXECUTE IMMEDIATE @sql;
                    IF @count > 0 THEN
                        SET result = CONCAT(
                            result, 'SELECT "Found ', @count, '" AS `found`, "',
                            tableName, '" AS `table`, "', columnName, '" AS `column` UNION ALL '
                        );
                    END IF;
                    SET sum = sum + 1;

                    IF sum > 1000 THEN
                        SET sum = 0;
                        SELECT 'Taking while, but still searching...' AS 'Please, wait...';
                    END IF;
                END LOOP;
                CLOSE cur;

                IF result = '' THEN
                    SELECT CONCAT('Sorry, I couldn\'t find `', cmd, '` anywhere in the database.') AS 'Results';
                ELSE
                    SET result = CONCAT(result, 'SELECT "---", "---", "---";');
                    EXECUTE IMMEDIATE result;
                END IF;
            END;
    END CASE;
END$$
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
delimiter $$

DROP PROCEDURE IF EXISTS `bin_magento_call_msi_sources_list`$$

CREATE PROCEDURE `bin_magento_call_msi_sources_list`(IN cmd VARCHAR(255))
COMMENT 'Listing all the MSI sources, use `--help` to see additional commands'
BEGIN
  CASE cmd
    WHEN '--help' THEN
      BEGIN
        SELECT ':::' AS 'help' UNION ALL
        SELECT '::: Use commands like:' AS 'help' UNION ALL
        SELECT ':::' AS 'help' UNION ALL
        SELECT '`msi:sources:list --help` - ℹ️ To see this help' AS 'help' UNION ALL
        SELECT '`msi:sources:list` - ℹ️ It lists all the MSI sources' AS 'help';
      END;
    ELSE
      BEGIN
        SELECT
          s.source_code AS `Code`,
          s.name AS `Name`,
          CASE s.enabled
            WHEN 1 THEN 'Enabled'
            ELSE 'Disabled'
          END AS `Status`,
          s.description AS `Description`,
          s.latitude AS `Latitude`,
          s.longitude AS `Longitude`,
          sc.country_id AS `Country`,
          scp.region_id AS `Region`,
          sc.region AS `Region Name`,
          sc.city AS `City`,
          sc.street AS `Street`,
          sc.postcode AS `Postcode`,
          sc.telephone AS `Phone`,
          sc.fax AS `Fax`
        FROM inventory_source s
        LEFT JOIN inventory_source_carrier_link scl ON s.source_code = scl.source_code
        LEFT JOIN inventory_source_address sc ON s.source_code = sc.source_code
        LEFT JOIN directory_country_region scp ON sc.region_id = scp.region_id
        GROUP BY s.source_code
        ORDER BY s.name ASC;
      END;
  END CASE;
END$$
DELIMITER $$

DROP PROCEDURE IF EXISTS `bin_magento_call_orders_list`$$

CREATE PROCEDURE `bin_magento_call_orders_list`(IN cmd VARCHAR(255))
    COMMENT 'Listing orders with filtering, pagination and detailed view'
BEGIN
    DECLARE isSQLOnly BOOLEAN DEFAULT FALSE;
    DECLARE pageSize INT DEFAULT 20;
    DECLARE page INT DEFAULT 1;
    DECLARE offsetVal INT DEFAULT 0;
    DECLARE orderFilter VARCHAR(255) DEFAULT NULL;
    DECLARE orderIdFilter INT DEFAULT NULL;
    DROP TEMPORARY TABLE IF EXISTS temp_order_results;
    CREATE TEMPORARY TABLE temp_order_results (
                                                  `section` VARCHAR(50),
                                                  `details` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    );

    main_block: BEGIN
        SET SESSION group_concat_max_len = 1000000;
        SET isSQLOnly = LOCATE('--sql', cmd) > 0;
        SET cmd = TRIM(REPLACE(cmd, '--sql', ''));

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

        SET offsetVal = (page - 1) * pageSize;
        SET cmd = TRIM(cmd);
        IF cmd != '' AND cmd != '--help' THEN
            SET orderFilter = cmd;
            SELECT entity_id INTO orderIdFilter
            FROM sales_order
            WHERE increment_id = orderFilter
            LIMIT 1;

            IF orderIdFilter IS NULL THEN
                INSERT INTO temp_order_results (`section`, `details`)
                VALUES ('Error', CONCAT('Order #', orderFilter, ' not found'));
                SELECT * FROM temp_order_results;
                DROP TEMPORARY TABLE temp_order_results;
                LEAVE main_block;
            END IF;
        END IF;

        CASE cmd
            WHEN '--help' THEN
                BEGIN
                    SELECT ':::' AS 'help' UNION ALL
                    SELECT '::: Use commands like:' AS 'help' UNION ALL
                    SELECT ':::' AS 'help' UNION ALL
                    SELECT '`orders:list --help`                    - ℹ️ To see this help' AS 'help' UNION ALL
                    SELECT '`orders:list`                           - ℹ️ It lists orders with pagination' AS 'help' UNION ALL
                    SELECT '`orders:list <order_number>`            - ℹ️ Shows detailed information for specific order' AS 'help' UNION ALL
                    SELECT '`<command> --pageSize=<number>`         - ℹ️ Sets number of items per page (default 20)' AS 'help' UNION ALL
                    SELECT '`<command> --page=<number>`             - ℹ️ Shows specific page number' AS 'help' UNION ALL
                    SELECT '`<command> --sql`                       - ℹ️ Shows SQL query without executing it' AS 'help';
                END;
            ELSE
                BEGIN
                    IF orderIdFilter IS NOT NULL THEN
                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Order Info',
                            CONCAT(
                                    'Order #: ', o.increment_id, '\n',
                                    'Date: ', o.created_at, '\n',
                                    'Status: ', o.status, '\n',
                                    'Grand Total: ', FORMAT(o.grand_total, 2), '\n',
                                    'Subtotal: ', FORMAT(o.subtotal, 2), '\n',
                                    'Shipping Amount: ', FORMAT(o.shipping_amount, 2), '\n',
                                    'Customer Email: ', o.customer_email, '\n',
                                    'Payment Method: ', COALESCE(p.method, 'Unknown'), '\n',
                                    'Shipping Method: ', COALESCE(o.shipping_description, 'Unknown')
                            )
                        FROM sales_order o
                                 LEFT JOIN sales_order_payment p ON o.entity_id = p.parent_id
                        WHERE o.entity_id = orderIdFilter;

                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Billing Address',
                            CONCAT(
                                    COALESCE(a.firstname, ''), ' ', COALESCE(a.lastname, ''), '\n',
                                    COALESCE(a.street, ''), '\n',
                                    COALESCE(a.city, ''), ', ',
                                    COALESCE(a.region, ''), ', ',
                                    COALESCE(a.postcode, ''), '\n',
                                    COALESCE(a.country_id, ''), '\n',
                                    'T: ', COALESCE(a.telephone, '')
                            )
                        FROM sales_order o
                                 LEFT JOIN sales_order_address a ON o.entity_id = a.parent_id AND a.address_type = 'billing'
                        WHERE o.entity_id = orderIdFilter;

                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Shipping Address',
                            CONCAT(
                                    COALESCE(a.firstname, ''), ' ', COALESCE(a.lastname, ''), '\n',
                                    COALESCE(a.street, ''), '\n',
                                    COALESCE(a.city, ''), ', ',
                                    COALESCE(a.region, ''), ', ',
                                    COALESCE(a.postcode, ''), '\n',
                                    COALESCE(a.country_id, ''), '\n',
                                    'T: ', COALESCE(a.telephone, '')
                            )
                        FROM sales_order o
                                 LEFT JOIN sales_order_address a ON o.entity_id = a.parent_id AND a.address_type = 'shipping'
                        WHERE o.entity_id = orderIdFilter;

                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Products',
                            COALESCE(
                                    GROUP_CONCAT(
                                            CONCAT(
                                                    'SKU: ', oi.sku, '\n',
                                                    'Name: ', oi.name, '\n',
                                                    'Price: ', FORMAT(oi.price, 2), '\n',
                                                    'Qty: ', oi.qty_ordered, '\n',
                                                    '-------------------'
                                            )
                                            SEPARATOR '\n'
                                    ),
                                    'No products'
                            )
                        FROM sales_order_item oi
                        WHERE oi.order_id = orderIdFilter;

                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Notes',
                            COALESCE(
                                    GROUP_CONCAT(
                                            CONCAT(
                                                    'Date: ', h.created_at, '\n',
                                                    'Status: ', h.status, '\n',
                                                    'Comment: ', COALESCE(h.comment, 'No comment'), '\n',
                                                    '-------------------'
                                            )
                                            SEPARATOR '\n'
                                    ),
                                    'No comments'
                            )
                        FROM sales_order_status_history h
                        WHERE h.parent_id = orderIdFilter;

                        INSERT INTO temp_order_results (`section`, `details`)
                        SELECT
                            'Invoices',
                            COALESCE(
                                    GROUP_CONCAT(
                                            CONCAT(
                                                    'Invoice #: ', i.increment_id, '\n',
                                                    'Date: ', i.created_at, '\n',
                                                    'Amount: ', FORMAT(i.grand_total, 2), '\n',
                                                    '-------------------'
                                            )
                                            SEPARATOR '\n'
                                    ),
                                    'No invoices'
                            )
                        FROM sales_invoice i
                        WHERE i.order_id = orderIdFilter;
                        SELECT * FROM temp_order_results;
                    ELSE
                        SET @sql = CONCAT(
                                'SELECT ',
                                'o.entity_id AS `Order ID`, ',
                                'o.increment_id AS `Order #`, ',
                                'o.created_at AS `Created At`, ',
                                'o.customer_email AS `Customer Email`, ',
                                'CONCAT(o.customer_firstname, " ", o.customer_lastname) AS `Customer Name`, ',
                                'o.grand_total AS `Grand Total`, ',
                                'o.total_qty_ordered AS `Total Items`, ',
                                'p.method AS `Payment Method`, ',
                                'o.shipping_description AS `Shipping Method`, ',
                                'o.status AS `Status`, ',
                                's.name AS `Store Name`, ',
                                'w.name AS `Website` ',
                                'FROM sales_order o ',
                                'JOIN store s ON o.store_id = s.store_id ',
                                'JOIN store_website w ON s.website_id = w.website_id ',
                                'LEFT JOIN sales_order_payment p ON o.entity_id = p.parent_id ',
                                'ORDER BY o.created_at DESC ',
                                'LIMIT ', offsetVal, ', ', pageSize
                                   );

                        IF isSQLOnly THEN
                            SELECT @sql AS 'SQL Query';
                        ELSE
                            EXECUTE IMMEDIATE @sql;
                        END IF;
                    END IF;
                END;
            END CASE;

        DROP TEMPORARY TABLE IF EXISTS temp_order_results;
    END main_block;
END$$
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
DELIMITER $$

DROP PROCEDURE IF EXISTS `bin_magento_call_themes_list`$$

CREATE PROCEDURE `bin_magento_call_themes_list`(IN p_cmd VARCHAR(255))
    COMMENT 'Listing all the themes, use `--help` to see additional commands'
BEGIN
    DECLARE is_full_view BOOLEAN DEFAULT FALSE;
    DECLARE p_title_filter VARCHAR(255) DEFAULT NULL;

    SET is_full_view = LOCATE('--full', p_cmd) > 0;
    SET p_cmd = TRIM(REPLACE(p_cmd, '--full', ''));

    IF p_cmd != '' AND p_cmd != '--help' THEN
        SET p_title_filter = TRIM(p_cmd);
    END IF;

    CASE p_cmd
        WHEN '--help' THEN
            BEGIN
                SELECT ':::' AS 'help' UNION ALL
                SELECT '::: Use commands like:' AS 'help' UNION ALL
                SELECT ':::' AS 'help' UNION ALL
                SELECT '`themes:list --help` - ℹ️ To see this help' AS 'help' UNION ALL
                SELECT '`themes:list` - ℹ️ It lists all the themes with hierarchy' AS 'help' UNION ALL
                SELECT '`themes:list <text>` - ℹ️ Filter themes by title' AS 'help' UNION ALL
                SELECT '`themes:list --full` - ℹ️ Show all theme columns' AS 'help';
            END;
        ELSE
            BEGIN
                IF is_full_view THEN
                    SELECT t.*
                    FROM theme t
                    WHERE p_title_filter IS NULL
                       OR t.theme_title LIKE CONCAT('%', p_title_filter, '%')
                    ORDER BY t.theme_path ASC;
                ELSE
                    WITH RECURSIVE theme_hierarchy AS (
                        SELECT
                            t.theme_id,
                            t.parent_id,
                            t.theme_title,
                            t.theme_path,
                            t.preview_image,
                            t.is_featured,
                            t.area,
                            0 AS level,
                            CAST(t.theme_id AS CHAR(200)) AS path
                        FROM theme t
                        WHERE t.parent_id IS NULL
                        UNION ALL
                        SELECT
                            c.theme_id,
                            c.parent_id,
                            c.theme_title,
                            c.theme_path,
                            c.preview_image,
                            c.is_featured,
                            c.area,
                            th.level + 1,
                            CONCAT(th.path, ',', c.theme_id)
                        FROM theme c
                                 JOIN theme_hierarchy th ON c.parent_id = th.theme_id
                    )
                    SELECT
                        CASE level
                            WHEN 0 THEN CONCAT('├── ', theme_id)
                            WHEN 1 THEN CONCAT('│   └── ', theme_id)
                            WHEN 2 THEN CONCAT('│       └── ', theme_id)
                            ELSE CONCAT('│', REPEAT('    ', level), '└── ', theme_id)
                            END AS `hierarchy`,
                        (SELECT
                             GROUP_CONCAT(DISTINCT s.code SEPARATOR ', ')
                         FROM core_config_data ccd
                                  JOIN store s ON ccd.scope_id = s.store_id
                         WHERE ccd.path = 'design/theme/theme_id'
                           AND ccd.scope = 'stores'
                           AND CAST(ccd.value AS UNSIGNED) = th.theme_id
                        ) AS `stores`,
                        th.area AS `area`,
                        th.theme_title AS `title`,
                        th.theme_path AS `name`,
                        th.preview_image AS `image`,
                        CASE th.is_featured
                            WHEN 1 THEN 'Featured'
                            ELSE ''
                            END AS `is_featured`
                    FROM theme_hierarchy th
                    WHERE p_title_filter IS NULL
                       OR th.theme_title LIKE CONCAT('%', p_title_filter, '%')
                    ORDER BY path;
                END IF;
            END;
        END CASE;
END$$
delimiter $$

DROP PROCEDURE IF EXISTS bin_magento_call_uninstall$$

CREATE PROCEDURE `bin_magento_call_uninstall`(IN cmd VARCHAR(255))
COMMENT 'Uninstall the bin_magento. It will delete all the procedures/functions of the bin_magento'
BEGIN
    CREATE TEMPORARY TABLE fixInfoSchemaSelectProblem
    SELECT routine_name as a, routine_type as b
    FROM information_schema.routines
    WHERE routine_schema = DATABASE()
      AND (routine_name LIKE 'bin_magento%')
      AND (routine_type = 'PROCEDURE' OR routine_type = 'FUNCTION');

    CASE cmd
        WHEN  '--help' THEN
            BEGIN
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '::: Use commands like:' AS 'help'
                    UNION ALL
                SELECT ':::' AS 'help'
                    UNION ALL
                SELECT '`uninstall --help`   - ℹ️ To see this help' AS 'help'
                    UNION ALL
                SELECT CONCAT('`uninstall`             ',
                       '- ℹ️ It will delete all the bin_magento procedures and functions') AS 'help';
            END;
        ELSE
            BEGIN
                DECLARE done INT DEFAULT 0;
                DECLARE finalCommand TEXT DEFAULT '';
                DECLARE routine_name VARCHAR(255);
                DECLARE routine_type VARCHAR(255);
                DECLARE cur CURSOR FOR
                    SELECT a, b
                    FROM fixInfoSchemaSelectProblem;

                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

                OPEN cur;
                read_loop: LOOP
                    FETCH cur INTO routine_name, routine_type;
                    IF done THEN
                        LEAVE read_loop;
                    END IF;
                    SET finalCommand = CONCAT(finalCommand, 'DROP ', routine_type, ' ', routine_name, ';
');
                END LOOP;

                CLOSE cur;

                SELECT CONCAT('`', finalCommand,'`') AS 'Ops, Manual query it is necessary.'
                    UNION ALL
                SELECT '
----------
Since I couldn\'t delete my own running procedure. Please copy and paste the above command:

After running it, Done, the procedures and functions of the bin_magento will be deleted.

Please, check my linkedin posts to get it again or check my other tools:
https://www.linkedin.com/in/henrique-kieckbusch-4786a239/

Thank you!
';
            END;
    END CASE;
    DROP TEMPORARY TABLE IF EXISTS fixInfoSchemaSelectProblem;
END$$

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
delimiter $$

DROP FUNCTION IF EXISTS bin_magento_get_eav$$

CREATE FUNCTION `bin_magento_get_eav`(table_name VARCHAR(64))
    RETURNS text
    DETERMINISTIC
BEGIN
  DECLARE column_name VARCHAR(9);
  DECLARE query TEXT;
  SET column_name = bin_magento_get_entity_column();

  SET query = CONCAT('
    SELECT DISTINCT
      ea.*,
      CASE
        WHEN ea.backend_type = ''varchar'' THEN cev.value
        WHEN ea.backend_type = ''int'' THEN cei.value
        WHEN ea.backend_type = ''text'' THEN cet.value
        WHEN ea.backend_type = ''decimal'' THEN ced.value
        WHEN ea.backend_type = ''datetime'' THEN cedt.value
      END AS value
    FROM ', table_name, '_entity AS ce
    JOIN eav_entity_type AS et ON et.entity_type_code = ''', table_name, '''
    JOIN eav_attribute AS ea ON et.entity_type_id = ea.entity_type_id
    LEFT JOIN ', table_name, '_entity_varchar AS cev
      ON ce.', column_name ,' = cev.', column_name ,' AND ea.attribute_id = cev.attribute_id
    LEFT JOIN ', table_name, '_entity_int AS cei
      ON ce.', column_name ,' = cei.', column_name ,' AND ea.attribute_id = cei.attribute_id
    LEFT JOIN ', table_name, '_entity_text AS cet
      ON ce.', column_name ,' = cet.', column_name ,' AND ea.attribute_id = cet.attribute_id
    LEFT JOIN ', table_name, '_entity_decimal AS ced
      ON ce.', column_name ,' = ced.', column_name ,' AND ea.attribute_id = ced.attribute_id
    LEFT JOIN ', table_name, '_entity_datetime AS cedt
      ON ce.', column_name ,' = cedt.', column_name ,' AND ea.attribute_id = cedt.attribute_id'
    );

    RETURN query;
END$$
DELIMITER $$

DROP FUNCTION IF EXISTS bin_magento_get_entity_column$$
CREATE FUNCTION `bin_magento_get_entity_column`()
    RETURNS TEXT
    DETERMINISTIC
BEGIN
    DECLARE column_name VARCHAR(9);
    DECLARE CONTINUE HANDLER FOR 1054
        BEGIN
            SET column_name = 'entity_id';
        END;
    SET column_name = 'row_id';
    DO (SELECT 1 FROM catalog_product_entity WHERE row_id IS NOT NULL LIMIT 1);
    RETURN column_name;
END$$
