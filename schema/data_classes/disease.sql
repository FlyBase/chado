
DROP TABLE IF EXISTS dataclass.disease CASCADE;

CREATE TABLE dataclass.disease
AS
SELECT db."name" || ':' || dbxr.accession AS id,
	cvt."name"
FROM cvterm cvt
JOIN cv
	ON (
		cvt.cv_id = cv.cv_id
		AND cv."name" = 'disease_ontology'
	)
JOIN dbxref dbxr
	ON cvt.dbxref_id = dbxr.dbxref_id
JOIN db
	ON (
		dbxr.db_id = db.db_id
		AND db."name" = 'DOID'
	)
;

ALTER TABLE dataclass.disease ADD PRIMARY KEY (id);

CREATE INDEX disease_idx1 ON dataclass.disease (id);
CREATE INDEX disease_idx2 ON dataclass.disease ("name");
