-- Expanding to include all gene_groups, may be some redundancy temporarily
DROP TABLE IF EXISTS dataclass.gene_group CASCADE;

CREATE TABLE dataclass.gene_group
AS
SELECT DISTINCT ON (grp.uniquename)
    grp.uniquename as id,
    s_fullname."name" as "name",
    s_fullname.synonym_sgml as name_sgml,
    s_symbol."name" as symbol,
    s_symbol.synonym_sgml as symbol_sgml,
    CONCAT(db_type."name",':',dbxr_type.accession) AS type_id,
    cvt_type."name" AS "type"
FROM grp
-- Add fullname
JOIN grp_synonym gs_fullname
    ON (
    	grp.grp_id = gs_fullname.grp_id
    	AND gs_fullname.is_current = TRUE
    	AND gs_fullname.is_internal = FALSE
	)
JOIN synonym s_fullname
    ON gs_fullname.synonym_id = s_fullname.synonym_id
JOIN cvterm cvt_fullname
    ON (
	    s_fullname.type_id = cvt_fullname.cvterm_id
	    AND cvt_fullname."name" = 'fullname'
    )
-- Add symbol
JOIN grp_synonym gs_symbol
    ON (
     	grp.grp_id = gs_symbol.grp_id
     	AND gs_symbol.is_current = TRUE
     	AND gs_symbol.is_internal = FALSE
    )
JOIN synonym s_symbol
    ON gs_symbol.synonym_id = s_symbol.synonym_id
JOIN cvterm cvt_symbol
    ON (
	    s_symbol.type_id = cvt_symbol.cvterm_id
	    AND cvt_symbol."name" = 'symbol'
    )
-- Add type
JOIN grp_cvterm gcvt_type
	ON grp.grp_id = gcvt_type.grp_id
JOIN cvterm cvt_type
	ON gcvt_type.cvterm_id = cvt_type.cvterm_id
JOIN dbxref dbxr_type
	ON cvt_type.dbxref_id = dbxr_type.dbxref_id
JOIN db db_type
	ON (
		dbxr_type.db_id = db_type.db_id
		AND UPPER(db_type."name") = 'FBCV'
	)
WHERE grp.uniquename ~ '^FBgg[0-9]+$'
    AND grp.is_analysis = FALSE
    AND grp.is_obsolete = FALSE
;

ALTER TABLE dataclass.gene_group ADD PRIMARY KEY (id);

CREATE INDEX gene_group_idx1 ON dataclass.gene_group ("name");
CREATE INDEX gene_group_idx2 ON dataclass.gene_group (name_sgml);
CREATE INDEX gene_group_idx3 ON dataclass.gene_group (symbol);
CREATE INDEX gene_group_idx4 ON dataclass.gene_group (symbol_sgml);
CREATE INDEX gene_group_idx5 ON dataclass.gene_group (type_id);
CREATE INDEX gene_group_idx6 ON dataclass.gene_group ("type");
