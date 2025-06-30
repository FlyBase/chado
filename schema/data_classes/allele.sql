/**
    //TODO: This query can be optimized similar to dataclass.gene. (removing DISTINCT)
*/
DROP TABLE IF EXISTS dataclass.allele CASCADE;

CREATE TABLE dataclass.allele
AS
SELECT DISTINCT ON (allele.uniquename)
    allele.uniquename AS id,
	s_fullname."name" AS "name",
	s_fullname.synonym_sgml AS name_sgml,
	s_symbol."name" AS symbol,
	s_symbol.synonym_sgml AS symbol_sgml
FROM feature allele
-- Add fullname
LEFT JOIN feature_synonym fs_fullname
    ON allele.feature_id = fs_fullname.feature_id
LEFT JOIN synonym s_fullname
    ON fs_fullname.synonym_id = s_fullname.synonym_id
LEFT JOIN cvterm cvt_fullname
    ON (
        s_fullname.type_id = cvt_fullname.cvterm_id
        AND cvt_fullname."name" = 'fullname'
    )
-- LEFT JOIN (
-- 	SELECT DISTINCT ON (fs_fullname.feature_id)
-- 		fs_fullname.feature_id,
-- 		s_fullname."name",
-- 		s_fullname.synonym_sgml
-- 	FROM feature_synonym fs_fullname
-- 	JOIN synonym s_fullname
--     	ON fs_fullname.synonym_id = s_fullname.synonym_id
-- 	JOIN cvterm cvt_fullname
-- 	    ON (
-- 		    s_fullname.type_id = cvt_fullname.cvterm_id
-- 		    AND cvt_fullname."name" = 'fullname'
-- 	    )
-- 	WHERE fs_fullname.is_current = TRUE
--     	AND fs_fullname.is_internal = FALSE
-- ) AS fullname
-- 	ON allele.feature_id = fullname.feature_id
-- Add symbol
LEFT JOIN feature_synonym fs_symbol
    ON allele.feature_id = fs_symbol.feature_id
LEFT JOIN synonym s_symbol
    ON fs_symbol.synonym_id = s_symbol.synonym_id
LEFT JOIN cvterm cvt_symbol
    ON (
        s_symbol.type_id = cvt_symbol.cvterm_id
        AND cvt_symbol."name" = 'symbol'
    )
-- LEFT JOIN (
-- 	SELECT DISTINCT ON (fs_symbol.feature_id)
-- 		fs_symbol.feature_id,
-- 		s_symbol."name",
-- 		s_symbol.synonym_sgml
-- 	FROM feature_synonym fs_symbol
-- 	JOIN synonym s_symbol
--     	ON fs_symbol.synonym_id = s_symbol.synonym_id
-- 	JOIN cvterm cvt_symbol
-- 	    ON (
-- 		    s_symbol.type_id = cvt_symbol.cvterm_id
-- 		    AND cvt_symbol."name" = 'symbol'
-- 	    )
-- 	WHERE fs_symbol.is_current = TRUE
--     	AND fs_symbol.is_internal = FALSE
-- ) AS symbol
-- 	ON allele.feature_id = symbol.feature_id
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

CREATE INDEX allele_idx1 ON dataclass.allele (id);
CREATE INDEX allele_idx2 ON dataclass.allele ("name");
CREATE INDEX allele_idx3 ON dataclass.allele (name_sgml);
CREATE INDEX allele_idx4 ON dataclass.allele (symbol);
CREATE INDEX allele_idx5 ON dataclass.allele (symbol_sgml);


