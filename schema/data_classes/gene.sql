
DROP TABLE IF EXISTS dataclass.gene CASCADE;

CREATE TABLE dataclass.gene
AS
SELECT
	gene.uniquename AS id,
	fullname."name" AS "name",
	fullname.synonym_sgml AS name_sgml,
	symbol."name" AS symbol,
	symbol.synonym_sgml AS symbol_sgml,
	gene.organism_id,
	aka.value AS aka,
	cytogenic_map.value AS cytogenic_map,
	pubs.value AS pubs,
	(
    	EXISTS (
            SELECT 1
            FROM featureprop fp_antibody
            JOIN cvterm cvt_antibody
                ON fp_antibody.type_id = cvt_antibody.cvterm_id
            WHERE fp_antibody.feature_id = gene.feature_id
                AND cvt_antibody."name" = 'reported_antibod_gen'
                AND cvt_antibody.is_obsolete = 0
        )
        OR
        EXISTS (
            SELECT 1
            FROM feature_dbxref gene_dbxr_antibody
            JOIN dbxref dbxr_antibody
                ON gene_dbxr_antibody.dbxref_id = dbxr_antibody.dbxref_id
            JOIN db db_antibody
                ON dbxr_antibody.db_id = db_antibody.db_id
            WHERE gene_dbxr_antibody.feature_id = gene.feature_id
                AND gene_dbxr_antibody.is_current = TRUE
                AND UPPER(db_antibody."name") IN ('DSHB', 'CST')
        )
	) AS antibody,
	testis_specificity_score.value AS testis_specificity_index
FROM feature gene
-- Add pubs
LEFT JOIN (
	SELECT fp_gene_pub.feature_id,
		ARRAY_AGG(DISTINCT gene_pub.uniquename) AS value
    FROM feature_pub fp_gene_pub
    JOIN pub gene_pub
    	ON (
    		fp_gene_pub.pub_id = gene_pub.pub_id
    		AND gene_pub.uniquename ~ '^FBrf[0-9]+$'
    		AND gene_pub.is_obsolete = false
    	)
    JOIN cvterm cvt_fp_gene_pub_type
    	ON (
    		gene_pub.type_id = cvt_fp_gene_pub_type.cvterm_id
        	AND cvt_fp_gene_pub_type."name" = 'paper'
        	AND cvt_fp_gene_pub_type.is_obsolete = 0
		)
	GROUP BY fp_gene_pub.feature_id
) AS pubs
	ON gene.feature_id = pubs.feature_id
-- Add cytogenic_map
LEFT JOIN (
	SELECT fp_cyto_range.feature_id,
		ARRAY_AGG(DISTINCT fp_cyto_range.value) AS value
	FROM featureprop fp_cyto_range
	JOIN cvterm cvt_fp_cyto_range_type
		ON (
			fp_cyto_range.type_id = cvt_fp_cyto_range_type.cvterm_id
			AND cvt_fp_cyto_range_type."name" = 'cyto_range'
			AND cvt_fp_cyto_range_type.is_obsolete = 0
		)
	GROUP BY fp_cyto_range.feature_id
) AS cytogenic_map
	ON gene.feature_id = cytogenic_map.feature_id
-- Add aka
LEFT JOIN (
	SELECT fp_aka.feature_id,
		STRING_AGG(DISTINCT fp_aka.value, ', ') AS value
	FROM featureprop fp_aka
	JOIN cvterm cvt_aka
		ON (
			fp_aka.type_id = cvt_aka.cvterm_id
			AND cvt_aka."name" = 'derived_aka_synonyms'
			AND cvt_aka.is_obsolete = 0
		)
	GROUP BY fp_aka.feature_id
) AS aka
	ON gene.feature_id = aka.feature_id
-- Add testis-specificity-index
LEFT JOIN (
	SELECT lf.feature_id, lfp.value
	FROM library_feature lf
	JOIN library_featureprop lfp
		ON lf.library_feature_id = lfp.library_feature_id
	JOIN cvterm cvt_lfp_type
		ON (
			lfp.type_id = cvt_lfp_type.cvterm_id
			AND cvt_lfp_type."name" = 'testis_specificity_index_score'
		)
) AS testis_specificity_score
	ON gene.feature_id = testis_specificity_score.feature_id
-- Add fullname
LEFT JOIN (
	SELECT DISTINCT ON (fs_fullname.feature_id)
		fs_fullname.feature_id,
		s_fullname."name",
		s_fullname.synonym_sgml
	FROM feature_synonym fs_fullname
	JOIN synonym s_fullname
    	ON fs_fullname.synonym_id = s_fullname.synonym_id
	JOIN cvterm cvt_fullname
	    ON (
		    s_fullname.type_id = cvt_fullname.cvterm_id
		    AND cvt_fullname."name" = 'fullname'
	    )
	WHERE fs_fullname.is_current = TRUE
    	AND fs_fullname.is_internal = FALSE
) AS fullname
	ON gene.feature_id = fullname.feature_id
-- Add symbol
LEFT JOIN (
	SELECT DISTINCT ON (fs_symbol.feature_id)
		fs_symbol.feature_id,
		s_symbol."name",
		s_symbol.synonym_sgml
	FROM feature_synonym fs_symbol
	JOIN synonym s_symbol
    	ON fs_symbol.synonym_id = s_symbol.synonym_id
	JOIN cvterm cvt_symbol
	    ON (
		    s_symbol.type_id = cvt_symbol.cvterm_id
		    AND cvt_symbol."name" = 'symbol'
	    )
	WHERE fs_symbol.is_current = TRUE
    	AND fs_symbol.is_internal = FALSE
) AS symbol
	ON gene.feature_id = symbol.feature_id
-- Filter out non-genes
WHERE gene.uniquename ~ '^FBgn[0-9]+$'
	AND gene.is_analysis = FALSE
	AND gene.is_obsolete = FALSE
;

ALTER TABLE dataclass.gene ADD PRIMARY KEY (id);

CREATE INDEX gene_idx1 ON dataclass.gene (id);
CREATE INDEX gene_idx2 ON dataclass.gene ("name");
CREATE INDEX gene_idx3 ON dataclass.gene (name_sgml);
CREATE INDEX gene_idx4 ON dataclass.gene (symbol);
CREATE INDEX gene_idx5 ON dataclass.gene (symbol_sgml);
CREATE INDEX gene_idx6 ON dataclass.gene (aka);
CREATE INDEX gene_idx7 ON dataclass.gene (antibody);
CREATE INDEX gene_idx8 ON dataclass.gene (organism_id);
CREATE INDEX gene_idx9 ON dataclass.gene (testis_specificity_index);


