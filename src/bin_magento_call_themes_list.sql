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
