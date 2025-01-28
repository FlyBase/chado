
DROP TABLE IF EXISTS dataclass.ortholog CASCADE;

CREATE TABLE dataclass.ortholog
AS
SELECT DISTINCT ON (ortholog.uniquename)
	ortholog.uniquename AS id,
	s_symbol."name" AS symbol,
	s_symbol.synonym_sgml AS symbol_sgml,
	ortholog.organism_id
FROM feature ortholog
-- Add symbol
JOIN feature_synonym fs_symbol
    ON (
    	ortholog.feature_id = fs_symbol.feature_id
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
-- grab FBog only
WHERE ortholog.uniquename ~ '^FBog[0-9]+$'
	AND ortholog.is_analysis = FALSE
	AND ortholog.is_obsolete = FALSE
;

ALTER TABLE dataclass.ortholog ADD PRIMARY KEY (id);

CREATE INDEX ortholog_idx1 ON dataclass.ortholog (id);
CREATE INDEX ortholog_idx2 ON dataclass.ortholog (symbol);
CREATE INDEX ortholog_idx3 ON dataclass.ortholog (symbol_sgml);
CREATE INDEX ortholog_idx4 ON dataclass.ortholog (organism_id);
