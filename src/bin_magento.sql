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
