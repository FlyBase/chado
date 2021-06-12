CREATE SCHEMA IF NOT EXISTS humanhealth;

DROP TABLE IF EXISTS humanhealth.allele_disease_variant CASCADE;
CREATE TABLE humanhealth.allele_disease_variant
AS
SELECT DISTINCT ON (fbhh_id, fbal_id) fbhh.uniquename                         AS fbhh_id,
                                      flybase.current_symbol(fbhh.uniquename) AS fbhh_symbol,
                                      fbgn.uniquename                         AS fbgn_id,
                                      fbgn.symbol                             AS fbgn_symbol,
                                      fbal.uniquename                         AS fbal_id,
                                      fbal.symbol                             AS fbal_symbol,
                                      flybase.current_symbol(div.uniquename)  AS div_designation,
                                      -- DIV synonyms in a JSON array.
                                      (SELECT jsonb_agg(distinct div_s.synonym_sgml)
                                       FROM feature_synonym div_fs
                                                JOIN synonym div_s ON div_fs.synonym_id = div_s.synonym_id AND
                                                                      div_fs.is_current = false AND
                                                                      div_fs.is_internal = false
                                                JOIN cvterm div_st ON div_s.type_id = div_st.cvterm_id
                                       WHERE div_fs.feature_id = div.feature_id
                                      )                                       AS div_synonym,
                                      -- Array of JSON objects that represent dbxref entries.
                                      (SELECT jsonb_agg(jsonb_build_object(
                                              'db', db.name,
                                              'accession', dbx.accession,
                                              'urlprefix', db.urlprefix
                                          ))
                                       FROM feature_dbxref fdbx
                                                JOIN dbxref dbx ON fdbx.dbxref_id = dbx.dbxref_id
                                                JOIN db on dbx.db_id = db.db_id
                                       WHERE fdbx.feature_id = div.feature_id
                                         AND fdbx.is_current = true
                                      )                                       AS dbxref,
                                      -- Comments
                                      CASE
                                          WHEN fbtp.uniquename IS NOT NULL
                                              THEN jsonb_build_array('Transgenic construct', fp1.value, fp2.value)
                                          ELSE jsonb_build_array('Alteration of endrogenous gene', fp1.value, fp2.value)
                                          END                                 AS comment,
                                      -- Array of JSON objects for the DIV publication.
                                      (SELECT jsonb_agg(jsonb_build_object(
                                              'fbid', p.uniquename,
                                              'miniref', p.miniref
                                          ))
                                       FROM flybase.get_featureprop(fbal.uniquename, 'disease_associated') AS fp
                                                JOIN featureprop_pub fpp ON fp.featureprop_id = fpp.featureprop_id
                                                JOIN pub p ON fpp.pub_id = p.pub_id AND p.is_obsolete = false
                                       WHERE flybase.data_class(p.uniquename) = 'FBrf'
                                      )                                       AS pubs,
                                      -- Array of FBrf IDs for all Allele pubs.
                                      (SELECT jsonb_agg(p.uniquename)
                                       FROM feature_pub fp
                                                JOIN pub p ON fp.pub_id = p.pub_id AND p.is_obsolete = false
                                       WHERE fp.feature_id = fbal.subject_id
                                         AND flybase.data_class(p.uniquename) = 'FBrf'
                                      )                                       AS fbal_pubs

FROM humanhealth AS fbhh
         JOIN humanhealth_feature hf ON fbhh.humanhealth_id = hf.humanhealth_id
         JOIN feature div ON hf.feature_id = div.feature_id AND div.is_obsolete = false
         JOIN cvterm dcvt ON div.type_id = dcvt.cvterm_id AND dcvt.name = 'disease implicated variant'
         JOIN flybase.get_feature_relationship(div.uniquename, 'has_variant', 'FBal') AS fbal
              ON (div.feature_id = fbal.object_id)
         JOIN flybase.get_feature_relationship(fbal.uniquename, 'alleleof', 'FBgn', 'object') AS fbgn
              ON (fbal.subject_id = fbgn.subject_id)
         LEFT JOIN flybase.get_feature_relationship(fbal.uniquename, 'associated_with', 'FBtp', 'object') AS fbtp
                   ON (fbal.subject_id = fbtp.subject_id)
         LEFT JOIN flybase.get_featureprop(fbal.uniquename, 'comment') AS fp1 ON (fbal.subject_id = fp1.feature_id)
         LEFT JOIN flybase.get_featureprop(fbal.uniquename, 'div_comment') AS fp2 ON (fbal.subject_id = fp2.feature_id)
;

CREATE INDEX humanhealth_div_idx1 ON humanhealth.allele_disease_variant (fbgn_id);
CREATE INDEX humanhealth_div_idx2 ON humanhealth.allele_disease_variant (fbal_id);
CREATE INDEX humanhealth_div_idx3 ON humanhealth.allele_disease_variant (fbhh_id);

CREATE OR REPLACE FUNCTION humanhealth.disease_variants_by_fbhh(fbhh text)
    RETURNS SETOF humanhealth.allele_disease_variant AS
$$
SELECT div.*
FROM humanhealth.allele_disease_variant AS div
WHERE div.fbhh_id = fbhh
    ;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION humanhealth.disease_variants_by_fbgn(fbgn text)
    RETURNS SETOF humanhealth.allele_disease_variant AS
$$
SELECT div.*
FROM humanhealth.allele_disease_variant AS div
WHERE div.fbgn_id = fbgn
    ;
$$ LANGUAGE SQL STABLE;
