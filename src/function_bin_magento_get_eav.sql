delimiter $$

DROP FUNCTION IF EXISTS bin_magento_get_eav$$

CREATE FUNCTION `bin_magento_get_eav`(table_name VARCHAR(64))
    RETURNS text
    DETERMINISTIC
BEGIN
  DECLARE column_name VARCHAR(9);
  DECLARE query TEXT;
  SET column_name = bin_magento_get_entity_column();

  SET query = CONCAT('
    SELECT DISTINCT
      ea.*,
      CASE
        WHEN ea.backend_type = ''varchar'' THEN cev.value
        WHEN ea.backend_type = ''int'' THEN cei.value
        WHEN ea.backend_type = ''text'' THEN cet.value
        WHEN ea.backend_type = ''decimal'' THEN ced.value
        WHEN ea.backend_type = ''datetime'' THEN cedt.value
      END AS value
    FROM ', table_name, '_entity AS ce
    JOIN eav_entity_type AS et ON et.entity_type_code = ''', table_name, '''
    JOIN eav_attribute AS ea ON et.entity_type_id = ea.entity_type_id
    LEFT JOIN ', table_name, '_entity_varchar AS cev
      ON ce.', column_name ,' = cev.', column_name ,' AND ea.attribute_id = cev.attribute_id
    LEFT JOIN ', table_name, '_entity_int AS cei
      ON ce.', column_name ,' = cei.', column_name ,' AND ea.attribute_id = cei.attribute_id
    LEFT JOIN ', table_name, '_entity_text AS cet
      ON ce.', column_name ,' = cet.', column_name ,' AND ea.attribute_id = cet.attribute_id
    LEFT JOIN ', table_name, '_entity_decimal AS ced
      ON ce.', column_name ,' = ced.', column_name ,' AND ea.attribute_id = ced.attribute_id
    LEFT JOIN ', table_name, '_entity_datetime AS cedt
      ON ce.', column_name ,' = cedt.', column_name ,' AND ea.attribute_id = cedt.attribute_id'
    );

    RETURN query;
END$$
