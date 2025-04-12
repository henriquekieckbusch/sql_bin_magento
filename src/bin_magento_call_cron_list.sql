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
