
DROP TABLE IF EXISTS dataclass.allele CASCADE;

CREATE TABLE dataclass.allele
SELECT DISTINCT ON (allele.uniquename)
	allele.uniquename AS id,
	s_fullname."name" AS "name",
	s_fullname.synonym_sgml AS name_sgml,
	s_symbol."name" AS symbol,
	s_symbol.synonym_sgml AS symbol_sgml,
	gene.uniquename AS gene_id
FROM feature allele
-- Add fullname
JOIN feature_synonym fs_fullname
    ON (
    	allele.feature_id = fs_fullname.feature_id
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
     	allele.feature_id = fs_symbol.feature_id
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
-- Add gene
LEFT JOIN feature_relationship fr_gene
    ON allele.feature_id = fr_gene.subject_id
LEFT JOIN cvterm cvt_fr_gene_type
    ON (
        fr_gene.type_id = cvt_fr_gene_type.cvterm_id
        AND cvt_fr_gene_type."name" = 'alleleof'
    )
LEFT JOIN feature gene
    ON gene.feature_id = fr_gene.object_id
-- Add propagate_transgenic_uses
LEFT JOIN featureprop fp_propagate_transgenic_uses
    ON (
        allele.feature_id = fp_propagate_transgenic_uses.feature_id
        AND fp_propagate_transgenic_uses.value != 'n'
    )
-- Filter out non-alleles
JOIN cvterm cvt_type
	ON (
		allele.type_id = cvt_type.cvterm_id
		AND cvt_type."name" = 'allele'
	)
WHERE allele.uniquename ~ '^FBal[0-9]+$'
	AND allele.is_analysis = FALSE
	AND allele.is_obsolete = FALSE

;

ALTER TABLE dataclass.allele ADD PRIMARY KEY (id);

ALTER TABLE dataclass.allele ADD CONSTRAINT allele_fk1 FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);

CREATE INDEX allele_idx1 ON dataclass.allele (id);
CREATE INDEX allele_idx2 ON dataclass.allele ("name");
CREATE INDEX allele_idx3 ON dataclass.allele (name_sgml);
CREATE INDEX allele_idx4 ON dataclass.allele (symbol);
CREATE INDEX allele_idx5 ON dataclass.allele (symbol_sgml);
