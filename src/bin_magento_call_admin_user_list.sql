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

