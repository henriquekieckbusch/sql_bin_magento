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

