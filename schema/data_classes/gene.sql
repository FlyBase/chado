
DROP TABLE IF EXISTS dataclass.gene CASCADE;

CREATE TABLE dataclass.gene
AS
SELECT DISTINCT ON (gene.uniquename)
	gene.uniquename AS id,
	s_fullname."name" AS "name",
	s_fullname.synonym_sgml AS name_sgml,
	s_symbol."name" AS symbol,
	s_symbol.synonym_sgml AS symbol_sgml,
	gene.organism_id,
	(
		SELECT STRING_AGG(fp_aka.value, ', ')
		FROM featureprop fp_aka
		JOIN cvterm cvt_aka
			ON fp_aka.type_id = cvt_aka.cvterm_id
		WHERE fp_aka.feature_id = gene.feature_id
			AND cvt_aka."name" = 'derived_aka_synonyms'
			AND cvt_aka.is_obsolete = 0
	) AS aka,
	(
	    SELECT (
	        (
	            SELECT COUNT(*) != 0
	            FROM featureprop fp_antibody
	            JOIN cvterm cvt_antibody
	                ON fp_antibody.type_id = cvt_antibody.cvterm_id
                WHERE fp_antibody.feature_id = gene.feature_id
                    AND cvt_antibody."name" = 'reported_antibod_gen'
                    AND cvt_antibody.is_obsolete = 0
	        )
	        OR
	        (
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
	        )
	    )
	) AS antibody,
	(
		SELECT JSONB_AGG(DISTINCT gene_pub.uniquename)
        FROM feature_pub fp_gene_pub
        JOIN pub gene_pub
        	USING (pub_id)
        JOIN cvterm cvt_fp_gene_pub_type
        	ON gene_pub.type_id = cvt_fp_gene_pub_type.cvterm_id
        WHERE fp_gene_pub.feature_id = gene.feature_id
        	AND gene_pub.uniquename ~ '^FBrf[0-9]+$'
        	AND gene_pub.is_obsolete = false
            AND cvt_fp_gene_pub_type."name" = 'paper'
	) AS pubs,
	(
		SELECT JSONB_AGG(DISTINCT fp_cyto_range.value)
		FROM featureprop fp_cyto_range
		JOIN cvterm cvt_fp_cyto_range_type
			ON (
				fp_cyto_range.type_id = cvt_fp_cyto_range_type.cvterm_id
				AND cvt_fp_cyto_range_type."name" = 'cyto_range'
			)
		WHERE fp_cyto_range.feature_id = gene.feature_id
	) AS cytogenic_map,
	testis_specificity.score AS testis_specificity_index
FROM feature gene
-- Add fullname
JOIN feature_synonym fs_fullname
    ON (
    	gene.feature_id = fs_fullname.feature_id
    	AND fs_fullname.is_current = TRUE
    	AND fs_fullname.is_internal = FALSE
	)
JOIN synonym s_fullname
    ON fs_fullname.synonym_id = s_fullname.synonym_id
JOIN cvterm cvt_fullname
    ON (
	    s_fullname.type_id = cvt_fullname.cvterm_id
	    AND cvt_fullname."name" = 'fullname'
    )
-- Add symbol
JOIN feature_synonym fs_symbol
    ON (
     	gene.feature_id = fs_symbol.feature_id
     	AND fs_symbol.is_current = TRUE
     	AND fs_symbol.is_internal = FALSE
    )
JOIN synonym s_symbol
    ON fs_symbol.synonym_id = s_symbol.synonym_id
JOIN cvterm cvt_symbol
    ON (
	    s_symbol.type_id = cvt_symbol.cvterm_id
	    AND cvt_symbol."name" = 'symbol'
    )
-- Add testis-specificity score
LEFT JOIN (
	SELECT DISTINCT
		lf.feature_id,
		lfp.value AS score
	FROM library_feature lf
	JOIN library_featureprop lfp
		ON lf.library_feature_id = lfp.library_feature_id
	JOIN cvterm cvt_lfp_type
		ON (
			lfp.type_id = cvt_lfp_type.cvterm_id
			AND cvt_lfp_type."name" = 'testis_specificity_index_score'
		)
) AS testis_specificity
	ON gene.feature_id = testis_specificity.feature_id
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
