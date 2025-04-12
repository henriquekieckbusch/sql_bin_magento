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
