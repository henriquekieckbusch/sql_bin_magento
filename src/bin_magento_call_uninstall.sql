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

