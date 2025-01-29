
DROP TABLE IF EXISTS dataclass.enzyme CASCADE;

CREATE TABLE dataclass.enzyme
AS
SELECT enzyme.accession AS id,
	dbxrp.value AS "name"
FROM dbxref enzyme
JOIN dbxrefprop dbxrp
	USING (dbxref_id)
JOIN cvterm cvt_dbxr_type
	ON (
		dbxrp.type_id = cvt_dbxr_type.cvterm_id
		AND cvt_dbxr_type."name" = 'ec_description'
	)
;

ALTER TABLE dataclass.enzyme ADD PRIMARY KEY (id);

CREATE INDEX enzyme_idx1 ON dataclass.enzyme (id);
CREATE INDEX enzyme_idx2 ON dataclass.enzyme ("name");
