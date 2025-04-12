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
