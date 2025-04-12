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
