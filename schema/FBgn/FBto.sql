create schema if not exists gene;

-- Drop table
drop table if exists gene.allele cascade;

-- Create table to hold all alleles.
DROP SEQUENCE IF EXISTS allele_id_seq;
CREATE SEQUENCE allele_id_seq;
create table gene.allele
  AS select
       nextval('allele_id_seq') as id,
       -- Gene feature.feature_id
       fbal.object_id AS fbgn_feature_id,
       -- Gene ID (FBgn)
       fbgn.uniquename AS fbgn_id,
       -- Gene symbol
       flybase.current_symbol(fbgn.uniquename) AS fbgn_symbol,
       -- Allele feature.feature_id
       fbal.subject_id AS fbal_feature_id,
       -- Allele ID (FBal)
       fbal.uniquename AS fbal_id,
       -- Allele symbol
       fbal.symbol AS fbal_symbol,
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
  from flybase.gene AS fbgn join flybase.get_feature_relationship(fbgn.uniquename,'alleleof','FBal') AS fbal on (fbgn.feature_id=fbal.object_id)
  where fbgn.uniquename in ('FBgn0033932','FBgn0022800','FBgn0010433','FBgn0030318')
;

alter table gene.allele add primary key (fbal_id);

-- /** Allele tool use **/
-- DROP TABLE IF EXISTS gene.allele_tool_use CASCADE;
-- DROP SEQUENCE IF EXISTS allele_tool_use_id_seq;
-- CREATE SEQUENCE allele_tool_use_id_seq;
-- CREATE TABLE gene.allele_tool_use
--   -- Get all tool_uses associated with the alleles.
--   AS SELECT DISTINCT ON (fbal.fbal_id, cvt.name)
--             nextval('allele_tool_use_id_seq') as id,
--             fbal.fbal_id,
--             cvt.name as name,
--             db.name || ':' || dbx.accession as fbcv_id
--        FROM gene.allele fbal JOIN feature_cvterm fcvt ON (fbal.fbal_feature_id = fcvt.feature_id)
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

-- /** Allele class table **/
-- DROP TABLE IF EXISTS gene.allele_class;
-- CREATE TABLE gene.allele_class
--   AS SELECT DISTINCT on (fbal.fbal_id, class.name)
--             fbal.fbal_id,
--             class.name,
--             db.name || ':' || dbx.accession as fbcv_id
--        FROM gene.allele fbal JOIN feature_cvterm fcvt ON (fbal.fbal_feature_id = fcvt.feature_id)
--                              JOIN cvterm class on (fcvt.cvterm_id = class.cvterm_id)
--                              JOIN dbxref dbx on (class.dbxref_id = dbx.dbxref_id)
--                              JOIN db on (dbx.db_id = db.db_id)
--                              JOIN cvtermprop cvtp on (class.cvterm_id = cvtp.cvterm_id)
--        WHERE cvtp.value = 'allele_class'
-- ;
 
--  /**
--  Table to hold the insertions that are directly associated with a particular allele.
--  **/
-- drop table if exists gene.insertion cascade;
-- create table gene.insertion
--   AS select fbgn_fbal.fbal_id,
--             fbti.uniquename AS fbti_id,
--             fbti.symbol AS fbti_symbol,
--             fbti.object_id as fbti_feature_id
--        from gene.allele AS fbgn_fbal
--             join
--             flybase.get_feature_relationship(fbgn_fbal.fbal_id, 'associated_with', 'FBti', 'object') AS fbti
--             on (fbgn_fbal.fbal_feature_id = fbti.subject_id)
-- ;
-- ALTER TABLE gene.insertion ADD PRIMARY KEY (fbti_id);
-- ALTER TABLE gene.insertion add constraint insertion_key1 unique (fbal_id, fbti_id);
-- ALTER TABLE gene.insertion ADD CONSTRAINT insertion_fk1 FOREIGN KEY (fbal_id) REFERENCES gene.allele (fbal_id);


-- /** 
-- Table to hold all constructs that are associated with the insertion

-- FBal ---<associated_with>---> FBti ---<produced_by>---> FBtp
-- **/
-- DROP TABLE IF EXISTS gene.insertion_construct CASCADE;
-- DROP SEQUENCE IF EXISTS insertion_construct_id_seq;
-- CREATE SEQUENCE insertion_construct_id_seq;
-- CREATE TABLE gene.insertion_construct
--   AS SELECT DISTINCT on (fbti.fbti_id, fbtp.uniquename)
--             nextval('insertion_construct_id_seq') as id,
--             fbti.fbti_id,
--             fbtp.uniquename AS fbtp_id,
--             fbtp.symbol AS fbtp_symbol,
--             fbtp.object_id as fbtp_feature_id
--        FROM gene.insertion AS fbti
--             join
--             flybase.get_feature_relationship(fbti.fbti_id, 'producedby', 'FBtp|FBmc|FBms', 'object') AS fbtp
--             on (fbti.fbti_feature_id = fbtp.subject_id)
-- ;
-- ALTER TABLE gene.insertion_construct ADD PRIMARY KEY (id);
-- CREATE INDEX insertion_construct_idx1 on gene.insertion_construct (fbtp_id);
-- ALTER TABLE gene.insertion_construct ADD CONSTRAINT insertion_construct_fk1 FOREIGN KEY (fbti_id) REFERENCES gene.insertion (fbti_id);

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
