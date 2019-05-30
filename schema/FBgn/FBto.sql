create schema if not exists gene;

-- Drop table
drop table if exists gene.allele cascade;

-- Create table to hold all alleles.
DROP SEQUENCE IF EXISTS allele_id_seq;
CREATE SEQUENCE allele_id_seq;
create table gene.allele
  AS SELECT
       nextval('allele_id_seq') as id,
       -- Allele ID (FBal)
       fbal.uniquename AS fbal_id,
       -- Allele symbol
       fbal.symbol AS symbol,
       /*
       A boolean field indicating whether or not the allele is a classical / insertion allele
       or is associated with transgenic construct.

       The test for a construct allele has two parts:

       1. Does the allele have an associated construct.
       OR
       2. Does the allele have an associated 'origin_of_mutation' cvterm that starts with 'in vitro construct'.
       */
       (exists (
          select 1
            from flybase.get_feature_relationship(fbal.uniquename, 'associated_with', 'FBtp|FBmc|FBms','object') AS fbtp
        )
        or
        exists (
          select 1
            from feature_cvterm fcvt join feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id=fcvtp.feature_cvterm_id)
                                     join cvterm cvt on (fcvt.cvterm_id=cvt.cvterm_id)
                                     join cvterm cvtp on (fcvtp.type_id=cvtp.cvterm_id)
            where cvtp.name = 'origin_of_mutation'
              -- FBcv term starting with 'in vitro construct'
              and position('in vitro construct' in lower(cvt.name)) = 0
              and fcvt.feature_id = fbal.subject_id
        )
       ) AS is_construct,
       (not exists (
            select 1 from flybase.get_featureprop(fbal.uniquename, 'propagate_transgenic_uses') fp
              where fp.value = 'n'
       )
       ) AS propagate_transgenic_uses
  FROM flybase.gene AS fbgn JOIN flybase.get_feature_relationship(fbgn.uniquename,'alleleof','FBal') AS fbal ON (fbgn.feature_id=fbal.object_id)
  WHERE fbgn.uniquename IN ('FBgn0033932','FBgn0022800','FBgn0010433','FBgn0030318')
;

ALTER TABLE gene.allele ADD PRIMARY KEY (id);
CREATE INDEX allele_idx1 on gene.allele (fbal_id);
CREATE INDEX allele_idx2 on gene.allele (symbol);
CREATE INDEX allele_idx3 on gene.allele (is_construct);
CREATE INDEX allele_idx4 on gene.allele (propagate_transgenic_uses);

/* Allele class table */
DROP TABLE IF EXISTS gene.allele_class;
DROP SEQUENCE IF EXISTS allele_class_id_seq;
CREATE SEQUENCE allele_class_id_seq;
CREATE TABLE gene.allele_class
  AS SELECT DISTINCT on (fbal.fbal_id, class.name)
            nextval('allele_class_id_seq') as id,
            fbal.id as allele_id,
            class.name,
            db.name || ':' || dbx.accession as fbcv_id
       FROM gene.allele fbal JOIN feature f ON (fbal.fbal_id = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN cvterm class on (fcvt.cvterm_id = class.cvterm_id)
                             JOIN dbxref dbx on (class.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
                             JOIN cvtermprop cvtp on (class.cvterm_id = cvtp.cvterm_id)
       WHERE cvtp.value = 'allele_class'
;
ALTER TABLE gene.allele_class ADD PRIMARY KEY (id);
ALTER TABLE gene.allele_class ADD CONSTRAINT allele_class_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
CREATE INDEX allele_class_idx1 on gene.allele_class (allele_id);
CREATE INDEX allele_class_idx2 on gene.allele_class (name);
CREATE INDEX allele_class_idx3 on gene.allele_class (fbcv_id);
 
 /*
 Table to hold the insertions that are directly associated with a particular allele.
 */
DROP TABLE IF EXISTS gene.insertion CASCADE;
DROP SEQUENCE IF EXISTS insertion_id_seq;
CREATE SEQUENCE insertion_id_seq;
CREATE TABLE gene.insertion
  AS SELECT DISTINCT ON (fbal.fbal_id, fbti.uniquename)
            nextval('insertion_id_seq') as id,
            fbal.id as allele_id,
            fbti.uniquename AS fbti_id,
            fbti.symbol AS symbol
       from gene.allele AS fbal JOIN feature f on (fbal.fbal_id = f.uniquename)
                                JOIN flybase.get_feature_relationship(fbal.fbal_id, 'associated_with', 'FBti', 'object') AS fbti
                                  on (f.feature_id = fbti.subject_id) 
;
ALTER TABLE gene.insertion ADD PRIMARY KEY (id);
ALTER TABLE gene.insertion ADD CONSTRAINT insertion_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
CREATE INDEX insertion_idx1 on gene.insertion (allele_id);
CREATE INDEX insertion_idx2 on gene.insertion (fbti_id);
CREATE INDEX insertion_idx3 on gene.insertion (symbol);


/*

*/
DROP TABLE IF EXISTS gene.construct CASCADE;
DROP SEQUENCE IF EXISTS construct_id_seq;
CREATE SEQUENCE construct_id_seq;
CREATE TABLE gene.construct
  AS SELECT DISTINCT on (fbti.fbti_id, fbtp.uniquename)
            nextval('construct_id_seq') as id,
            fbtp.uniquename AS fbtp_id,
            fbtp.symbol AS symbol,
            fbti.id as insertion_id,
            NULL as allele_id
       FROM gene.insertion AS fbti join feature f on (fbti.fbti_id = f.uniquename)
              join flybase.get_feature_relationship(fbti.fbti_id, 'producedby', 'FBtp|FBmc|FBms', 'object') AS fbtp
                on (f.feature_id = fbtp.subject_id)
     UNION
     SELECT DISTINCT on (fbal.fbal_id, fbtp.uniquename)
            nextval('construct_id_seq') as id,
            fbtp.uniquename AS fbtp_id,
            fbtp.symbol AS symbol,
            NULL as insertion_id,
            fbal.id as allele_id
       FROM gene.allele AS fbal join feature f on (fbal.fbal_id = f.uniquename)
              join flybase.get_feature_relationship(fbal.fbal_id, 'associated_with', 'FBtp|FBmc|FBms', 'object') AS fbtp
                on (f.feature_id = fbtp.subject_id)

;
ALTER TABLE gene.construct ADD PRIMARY KEY (id);
CREATE INDEX construct_idx1 on gene.construct (fbtp_id);
CREATE INDEX construct_idx2 on gene.construct (symbol);
CREATE INDEX construct_idx3 on gene.construct (insertion_id);
CREATE INDEX construct_idx4 on gene.construct (allele_id);
ALTER TABLE gene.construct ADD CONSTRAINT construct_fk1 FOREIGN KEY (insertion_id) REFERENCES gene.insertion (id);
ALTER TABLE gene.construct ADD CONSTRAINT construct_fk2 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);

-- /** Insertion construct tool use **/
-- DROP TABLE IF EXISTS gene.insertion_construct_tool_use CASCADE;
-- DROP SEQUENCE IF EXISTS insertion_construct_tool_use_id_seq;
-- CREATE SEQUENCE insertion_construct_tool_use_id_seq;
-- CREATE TABLE gene.insertion_construct_tool_use
--   -- Get all tool_uses associated with the insertion construct.
--   AS SELECT DISTINCT ON (fbtp.fbtp_id, cvt.name)
--             nextval('insertion_construct_tool_use_id_seq') as id,
--             fbtp.fbtp_id,
--             cvt.name as name,
--             db.name || ':' || dbx.accession as fbcv_id
--        FROM gene.insertion_construct fbtp JOIN feature_cvterm fcvt ON (fbal.fbal_feature_id = fcvt.feature_id)
--                              JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
--                              JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
--                              JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
--                              JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
--                              JOIN db on (dbx.db_id = db.db_id)
--        WHERE fcvtp_type.name = 'tool_uses'
-- ;

-- ALTER TABLE gene.allele_tool_use ADD PRIMARY KEY (id);
-- CREATE INDEX tool_use_idx1 on gene.allele_tool_use (fbcv_id);
-- CREATE INDEX tool_use_idx2 on gene.allele_tool_use (name);
-- ALTER TABLE gene.allele_tool_use ADD CONSTRAINT tool_use_fk1 FOREIGN KEY (fbid) REFERENCES gene.allele (fbal_id);

-- /** 
-- Table to hold all constructs that are associated with the allele

-- FBal ---<associated_with>---> FBtp
-- **/
-- DROP TABLE IF EXISTS gene.associated_construct CASCADE;
-- CREATE TABLE gene.associated_construct
--   AS select fbgn_fbal.fbal_id,
--             fbtp.uniquename AS fbtp_id,
--             fbtp.symbol AS fbtp_symbol,
--             fbtp.object_id as fbtp_feature_id
--        from gene.allele AS fbgn_fbal
--             join
--             flybase.get_feature_relationship(fbgn_fbal.fbal_id, 'associated_with', 'FBtp|FBmc|FBms', 'object') AS fbtp
--             on (fbgn_fbal.fbal_feature_id = fbtp.subject_id)
-- ;
-- ALTER TABLE gene.associated_construct ADD CONSTRAINT associated_construct_fk1 FOREIGN KEY (fbal_id) REFERENCES gene.allele (fbal_id);

-- /**

-- Tools that are associated with the construct.

-- **/
-- DROP TABLE IF EXISTS gene.construct_tool CASCADE;
-- DROP SEQUENCE IF EXISTS construct_tool_id_seq;
-- CREATE SEQUENCE construct_tool_id_seq;
-- CREATE TABLE gene.construct_tool
--   AS SELECT DISTINCT on (fbtp.fbtp_id, fbto.uniquename)
--             nextval('construct_tool_id_seq') as id,
--             fbtp.id as insertion_construct_id,
--             fbto.uniquename AS fbto_id,
--             fbto.symbol AS fbto_symbol,
--             fbto.object_id as fbto_feature_id
--        FROM gene.insertion_construct AS fbtp
--             join
--             flybase.get_feature_relationship(fbtp.fbtp_id, 'has_reg_region|encodes_tool|carries_tool|tagged_with', 'FBto', 'object') AS fbto
--             on (fbtp.fbtp_feature_id = fbto.subject_id)
-- ;
-- ALTER TABLE gene.construct_tool ADD PRIMARY KEY (id);
-- CREATE INDEX construct_tool_idx1 on gene.construct_tool (fbto_id);
-- ALTER TABLE gene.construct_tool ADD CONSTRAINT construct_tool_fk1 FOREIGN KEY (insertion_construct_id) REFERENCES gene.insertion_construct (id);

-- /**

-- Tools that are associated with the allele.

-- **/
-- DROP TABLE IF EXISTS gene.allele_tool CASCADE;
-- CREATE TABLE gene.allele_tool
--   AS SELECT fbgn_fbal.fbal_id,
--             FBto.uniquename AS fbto_id,
--             FBto.symbol AS fbto_symbol,
--             FBto.type AS rel_type
--        FROM gene.allele AS fbgn_fbal
--             join
--             flybase.get_feature_relationship(fbgn_fbal.fbal_id, 'has_reg_region|encodes_tool|carries_tool|tagged_with', 'FBto', 'object') AS FBto
--             on (fbgn_fbal.fbal_feature_id = fbto.subject_id)
-- ;

-- ALTER TABLE gene.allele_tool ADD CONSTRAINT tool_fk1 FOREIGN KEY (fbal_id) REFERENCES gene.allele (fbal_id);

/* Tool Use */
DROP TABLE IF EXISTS gene.tool_use CASCADE;
DROP SEQUENCE IF EXISTS tool_use_id_seq;
CREATE SEQUENCE tool_use_id_seq;
CREATE TABLE gene.tool_use
  -- Get all tool_uses associated with the alleles.
  AS SELECT DISTINCT ON (fbal.fbal_id, cvt.name)
            nextval('tool_use_id_seq') as id,
            cvt.name as name,
            db.name || ':' || dbx.accession as fbcv_id,
            fbal.id as allele_id,
            NULL as construct_id,
            NULL as tool_id
       FROM gene.allele fbal JOIN feature f ON (fbal.fbal_id = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
                             JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
                             JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
                             JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
       WHERE fcvtp_type.name = 'tool_uses'
     UNION
     SELECT DISTINCT ON (fbtp.fbtp_id, cvt.name)
            nextval('tool_use_id_seq') as id,
            cvt.name as name,
            db.name || ':' || dbx.accession as fbcv_id,
            NULL as allele_id,
            fbtp.id as construct_id,
            NULL as tool_id
       FROM gene.construct fbtp JOIN feature f ON (fbtp.fbtp_id = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
                             JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
                             JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
                             JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
       WHERE fcvtp_type.name = 'tool_uses'
;

ALTER TABLE gene.tool_use ADD PRIMARY KEY (id);
CREATE INDEX tool_use_idx1 on gene.tool_use (fbcv_id);
CREATE INDEX tool_use_idx2 on gene.tool_use (name);
CREATE INDEX tool_use_idx3 on gene.tool_use (allele_id);
CREATE INDEX tool_use_idx4 on gene.tool_use (construct_id);
CREATE INDEX tool_use_idx5 on gene.tool_use (tool_id);
ALTER TABLE gene.tool_use ADD CONSTRAINT tool_use_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
ALTER TABLE gene.tool_use ADD CONSTRAINT tool_use_fk2 FOREIGN KEY (construct_id) REFERENCES gene.construct (id);