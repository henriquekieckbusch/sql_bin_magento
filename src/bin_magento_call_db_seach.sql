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
