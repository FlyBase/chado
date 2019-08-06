CREATE SCHEMA IF NOT EXISTS gene;

-- Drop table
DROP TABLE IF EXISTS gene.allele cascade;

-- Create table to hold all alleles.
CREATE TABLE gene.allele
  AS SELECT
       -- Allele ID (FBal)
       fbal.uniquename AS fbal_id,
       -- Allele symbol
       fbal.symbol AS symbol,
       fbgn.feature_id AS gene_id,
       /*
        * A boolean field indicating whether or not the allele is a classical / insertion allele
        * or is associated with transgenic construct.
        *
        * The test for a construct allele has two parts:
        *
        * 1. Does the allele have an associated construct.
        * OR
        * 2. Does the allele have an associated 'origin_of_mutation' cvterm that starts with 'in vitro construct'.
        */
       (exists (
          select 1
            from flybase.get_feature_relationship(fbal.uniquename, 'associated_with', 'FBtp|FBmc|FBms','object') AS fbtp
        )
        or
        exists (
          select 1
            from feature_cvterm fcvt join cvterm cvt on (fcvt.cvterm_id=cvt.cvterm_id)
                                     join cvtermprop cvtp on (cvt.cvterm_id=cvtp.cvterm_id)
            where cvtp.value = 'origin_of_mutation'
              -- FBcv term starting with 'in vitro construct'
              and position('in vitro construct' in lower(cvt.name)) = 1
              and fcvt.feature_id = fbal.subject_id
        )
       ) AS is_construct,
       (not exists (
            select 1 from flybase.get_featureprop(fbal.uniquename, 'propagate_transgenic_uses') fp
              where fp.value = 'n'
       )
       ) AS propagate_transgenic_uses,
       false AS gene_is_regulatory_region
     FROM gene.gene AS fbgn
                 JOIN
                   flybase.get_feature_relationship(fbgn.uniquename,'alleleof','FBal') AS fbal
                   ON (fbgn.feature_id=fbal.object_id)
      
     UNION
      /*
       * Transgenic constructs containing regulatory region of gene X.
       * Method 1 from Gillian (WEB-1015).
       */
     SELECT
        -- Allele ID (FBal)
        fbal.uniquename AS fbal_id,
        -- Allele symbol
        fbal.symbol AS symbol,
        fbgn.feature_id AS gene_id,
        -- True by default.
        true AS is_construct,
        true AS propagate_transgenic_uses,
        true AS gene_is_regulatory_region
     FROM gene.gene AS fbgn
                 JOIN
                   flybase.get_feature_relationship(fbgn.uniquename,'has_reg_region','FBal') AS fbal
                   ON (fbgn.feature_id=fbal.object_id)
     UNION
      /*
       * Transgenic constructs containing regulatory region of gene X.
       * Method 2 from Gillian (WEB-1015).
       */
      SELECT
        -- Allele ID (FBal)
        fbal.uniquename AS fbal_id,
        -- Allele symbol
        fbal.symbol AS symbol,
        fbgn.feature_id AS gene_id,
        true AS is_construct,
        true AS propagate_transgenic_uses,
        true AS gene_is_regulatory_region
      FROM gene.gene AS fbgn
                 JOIN
                   flybase.get_feature_relationship(fbgn.uniquename,'attributed_as_expression_of','FBtr|FBpp') AS fbtr_fbpp
                   ON (fbgn.feature_id=fbtr_fbpp.object_id)
                 JOIN 
                   flybase.get_feature_relationship(fbtr_fbpp.uniquename, 'associated_with','FBal', 'object') AS fbal
                   ON (fbtr_fbpp.subject_id=fbal.subject_id)
                 JOIN
                   flybase.get_feature_relationship(fbal.uniquename, 'associated_with', 'FBtp', 'object') AS fbtp
                   ON (fbal.object_id=fbtp.subject_id)
                 JOIN
                   flybase.get_feature_relationship(fbal.uniquename, 'encodes_tool', 'FBto', 'object') AS fbto
                   ON (fbal.object_id=fbto.subject_id)
      UNION
      /*
       * Transgenic constructs containing regulatory region of gene X.
       * Method 3 from Gillian (WEB-1015).
       * NOT IMPLEMENTED IN CHADO YET
       */
      SELECT
        -- Allele ID (FBal)
        fbal.uniquename AS fbal_id,
        -- Allele symbol
        fbal.symbol AS symbol,
        fbgn.feature_id AS gene_id,
        true AS is_construct,
        true AS propagate_transgenic_uses,
        true AS gene_is_regulatory_region
      FROM gene.gene AS fbgn
                 JOIN
                   flybase.get_feature_relationship(fbgn.uniquename,'associated_with','FBsf') AS fbsf
                   ON (fbgn.feature_id=fbsf.object_id)
                 JOIN 
                   flybase.get_feature_relationship(fbsf.uniquename, 'has_reg_region','FBal') AS fbal
                   ON (fbsf.object_id=fbal.object_id)             
;

ALTER TABLE gene.allele ADD COLUMN id SERIAL PRIMARY KEY;

-- Add and populate a stocks count column.
ALTER TABLE gene.allele ADD COLUMN stocks_count bigint DEFAULT 0;
UPDATE gene.allele SET stocks_count = (select count(*) from flybase.get_stocks(fbal_id));

-- Add and populate a pub count column.
ALTER TABLE gene.allele ADD COLUMN pub_count bigint DEFAULT 0;
UPDATE gene.allele SET pub_count = (select flybase.pub_count(fbal_id));

-- Add and populate a known lesion column.
ALTER TABLE gene.allele ADD COLUMN known_lesion boolean DEFAULT false;
UPDATE gene.allele SET known_lesion = (SELECT COUNT(*) != 0 FROM flybase.get_featureprop(fbal_id,'known_lesion'));

ALTER TABLE gene.allele ADD CONSTRAINT allele_fk1 FOREIGN KEY (gene_id) REFERENCES gene.gene (feature_id);
--CREATE UNIQUE INDEX CONCURRENTLY allele_idx1 on gene.allele (fbal_id);
--ALTER TABLE gene.allele ADD CONSTRAINT unique_fbal_id UNIQUE USING INDEX allele_idx1;
CREATE INDEX allele_idx1 ON gene.allele (fbal_id);
CREATE INDEX allele_idx2 ON gene.allele (symbol);
CREATE INDEX allele_idx3 ON gene.allele (is_construct);
CREATE INDEX allele_idx4 ON gene.allele (propagate_transgenic_uses);
CREATE INDEX allele_idx5 ON gene.allele (gene_is_regulatory_region);
CREATE INDEX allele_idx6 ON gene.allele (stocks_count);
CREATE INDEX allele_idx7 ON gene.allele (known_lesion);
CREATE INDEX allele_idx8 ON gene.allele (pub_count);

/* Allele class table */
DROP TABLE IF EXISTS gene.allele_class;
CREATE TABLE gene.allele_class
  AS SELECT DISTINCT on (fbal.id, fbcv_id)
            fbal.id as allele_id,
            split_class[1] as fbcv_id,
            split_class[2] as name
        FROM (
          /*
           * Takes a sincle promoted allele class with stamps and it trims the stamps and whitespace,
           * then splits on the colon ':', and returns the id/name as an array of 2 elements.
           */
          SELECT uniquename, regexp_split_to_array(trim(both ' @' from allele_class), ':') AS split_class FROM
            /* 
             * Selects all promoted_allele_class featureprops and splits those with multiple 
             * classes delimited by a comma into multiple result rows.
             * i.e.
             * This single string "@FBcv0123:name1@, @FBcv0124:name2@" is turned into two result rows.
             */
            (SELECT f.uniquename, regexp_split_to_table(fp.value, ',') AS allele_class
               FROM featureprop fp JOIN cvterm fpt ON (fp.type_id = fpt.cvterm_id)
                                   JOIN feature f ON (fp.feature_id = f.feature_id)
               WHERE fpt.name = 'promoted_allele_class'
            ) AS tmp1
        ) AS tmp2
        JOIN gene.allele fbal ON (tmp2.uniquename = fbal.fbal_id)
;
ALTER TABLE gene.allele_class ADD COLUMN id SERIAL PRIMARY KEY;
ALTER TABLE gene.allele_class ADD CONSTRAINT allele_class_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
CREATE INDEX allele_class_idx1 ON gene.allele_class (allele_id);
CREATE INDEX allele_class_idx2 ON gene.allele_class (name);
CREATE INDEX allele_class_idx3 ON gene.allele_class (fbcv_id);
 
/* Allele stock table */
DROP TABLE IF EXISTS gene.allele_stock;
CREATE TABLE gene.allele_stock
  AS SELECT DISTINCT ON (fbal.id, stock.fbst)
            fbal.id as allele_id,
            stock.fbst as fbst_id,
            stock.center as center,
            stock.stock_number as stock_number,
            stock.genotype as genotype
     FROM gene.allele as fbal JOIN flybase.get_stocks(fbal.fbal_id) AS stock ON (fbal.fbal_id = stock.fbid)
;
ALTER TABLE gene.allele_stock ADD COLUMN id SERIAL PRIMARY KEY;
ALTER TABLE gene.allele_stock ADD CONSTRAINT allele_stock_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
CREATE INDEX allele_stock_idx1 ON gene.allele_stock (allele_id);
CREATE INDEX allele_stock_idx2 ON gene.allele_stock (fbst_id);
CREATE INDEX allele_stock_idx3 ON gene.allele_stock (center);
CREATE INDEX allele_stock_idx4 ON gene.allele_stock (stock_number);
CREATE INDEX allele_stock_idx5 ON gene.allele_stock (genotype);

/* Allele mutagen table */
DROP TABLE IF EXISTS gene.allele_mutagen;
CREATE TABLE gene.allele_mutagen
  AS SELECT DISTINCT ON (fbal.id, dbx.accession)
            fbal.id as allele_id,
            db.name || ':' || dbx.accession AS fbcv_id,
            cvt.name AS name
     FROM gene.allele as fbal JOIN feature f ON (fbal.fbal_id = f.uniquename)
                              JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                              JOIN cvterm cvt ON (fcvt.cvterm_id = cvt.cvterm_id)
                              JOIN cvtermprop cvtp ON (cvt.cvterm_id = cvtp.cvterm_id)
                              JOIN dbxref dbx ON (cvt.dbxref_id = dbx.dbxref_id)
                              JOIN db ON (dbx.db_id = db.db_id)
     WHERE cvtp.value = 'origin_of_mutation'
;
ALTER TABLE gene.allele_mutagen ADD COLUMN id SERIAL PRIMARY KEY;
ALTER TABLE gene.allele_mutagen ADD CONSTRAINT allele_mutagen_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
CREATE INDEX allele_mutagen_idx1 ON gene.allele_mutagen (allele_id);
CREATE INDEX allele_mutagen_idx2 ON gene.allele_mutagen (fbcv_id);
CREATE INDEX allele_mutagen_idx3 ON gene.allele_mutagen (name);

 /*
  * Table to hold the insertions that are directly associated with a particular allele.
  */
DROP TABLE IF EXISTS gene.insertion CASCADE;
CREATE TABLE gene.insertion
  AS SELECT DISTINCT ON (fbal.id, fbti.uniquename)
            fbti.uniquename AS fbti_id,
            fbti.symbol AS symbol,
            fbal.id AS allele_id,
            NULL::bigint AS gene_id
       FROM gene.allele AS fbal JOIN feature f on (fbal.fbal_id = f.uniquename)
                                JOIN flybase.get_feature_relationship(fbal.fbal_id, 'associated_with', 'FBti', 'object') AS fbti
                                  ON (f.feature_id = fbti.subject_id) 
     UNION
     /*
      * The following select pulls in insertions that are known to be expressed in 
      * the pattern of gene X, but which are not know to cause an allele of gene X.
      */
     SELECT DISTINCT ON (fbgn.feature_id, fbti.uniquename)
            fbti.uniquename AS fbti_id,
            fbti.symbol AS symbol,
            NULL::bigint AS allele_id,
            fbgn.feature_id AS gene_id
       FROM gene.gene AS fbgn JOIN flybase.get_feature_relationship(fbgn.uniquename, 'attributed_as_expression_of','FBtr|FBpp') AS fbtr_fbpp
                                   ON fbgn.feature_id = fbtr_fbpp.object_id
                                 JOIN flybase.get_feature_relationship(fbtr_fbpp.uniquename,'associated_with','FBal','object') AS fbal
                                   ON fbtr_fbpp.subject_id = fbal.subject_id
                                 JOIN flybase.get_feature_relationship(fbal.uniquename,'associated_with','FBti','object') as fbti
                                   ON fbal.object_id = fbti.subject_id
       WHERE 
         /** Make sure it doesn't have an associated allele **/
         NOT EXISTS (
           SELECT 1
             FROM flybase.get_feature_relationship(fbti.uniquename,'associated_with','FBal') as fbal2
               JOIN flybase.get_feature_relationship(fbal2.uniquename,'alleleof','FBgn','object') as fbgn2
                 ON fbal2.subject_id = fbgn2.subject_id
             WHERE fbgn2.object_id = fbgn.feature_id
         )
     UNION
     /*
      * The following query pulls in insertions that overlap with the gene span.
      * It uses the built-in chado function feature_overlaps to perform that logic.
      */
     SELECT DISTINCT ON (fbgn.feature_id, fbti.uniquename)
            fbti.uniquename AS fbti_id,
            flybase.current_symbol(fbti.uniquename) AS symbol,
            NULL::bigint AS allele_id,
            fbgn.feature_id AS gene_id
       FROM gene.gene AS fbgn LEFT JOIN LATERAL feature_overlaps(fbgn.feature_id) fbti ON TRUE
       WHERE -- fbgn.uniquename IN ('FBgn0033932','FBgn0022800','FBgn0010433','FBgn0004635','FBgn0039290')
         -- AND
         flybase.data_class(fbti.uniquename) = 'FBti'
         /** Make sure it doesn't have an associated allele **/
         AND NOT EXISTS (
           SELECT 1
             FROM flybase.get_feature_relationship(fbti.uniquename,'associated_with','FBal') as fbal2
               JOIN flybase.get_feature_relationship(fbal2.uniquename,'alleleof','FBgn','object') as fbgn2
                 ON fbal2.subject_id = fbgn2.subject_id
             WHERE fbgn2.object_id = fbgn.feature_id
         )
;
ALTER TABLE gene.insertion ADD COLUMN id SERIAL PRIMARY KEY;

-- Add and populate a stocks count column.
ALTER TABLE gene.insertion ADD COLUMN stocks_count bigint DEFAULT 0;
UPDATE gene.insertion SET stocks_count = (select count(*) from flybase.get_stocks(fbti_id));

-- Add and populate a pub count column.
ALTER TABLE gene.insertion ADD COLUMN pub_count bigint DEFAULT 0;
UPDATE gene.insertion SET pub_count = (select flybase.pub_count(fbti_id));

ALTER TABLE gene.insertion ADD CONSTRAINT insertion_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
ALTER TABLE gene.insertion ADD CONSTRAINT insertion_fk2 FOREIGN KEY (gene_id) REFERENCES gene.gene (feature_id);
CREATE INDEX insertion_idx1 on gene.insertion (allele_id);
CREATE INDEX insertion_idx2 on gene.insertion (fbti_id);
CREATE INDEX insertion_idx3 on gene.insertion (symbol);
CREATE INDEX insertion_idx4 on gene.insertion (gene_id);
CREATE INDEX insertion_idx5 on gene.insertion (stocks_count);
CREATE INDEX insertion_idx6 on gene.insertion (pub_count);

/*
 * Constructs that are either produced by an insertion or 
 * associated with an allele.
 */
DROP TABLE IF EXISTS gene.construct CASCADE;
CREATE TABLE gene.construct
  AS SELECT 
            fbtp.uniquename AS fbtp_id,
            fbtp.symbol AS symbol,
            fbti.id as insertion_id,
            NULL::bigint as allele_id
       FROM gene.insertion AS fbti join feature f on (fbti.fbti_id = f.uniquename)
              join flybase.get_feature_relationship(fbti.fbti_id, 'producedby', 'FBtp|FBmc|FBms', 'object') AS fbtp
                on (f.feature_id = fbtp.subject_id)
     UNION
     SELECT 
            fbtp.uniquename AS fbtp_id,
            fbtp.symbol AS symbol,
            NULL::bigint as insertion_id,
            fbal.id as allele_id
       FROM gene.allele AS fbal join feature f on (fbal.fbal_id = f.uniquename)
              join flybase.get_feature_relationship(fbal.fbal_id, 'associated_with', 'FBtp|FBmc|FBms', 'object') AS fbtp
                on (f.feature_id = fbtp.subject_id)

;
ALTER TABLE gene.construct ADD COLUMN id SERIAL PRIMARY KEY;
CREATE INDEX construct_idx1 on gene.construct (fbtp_id);
CREATE INDEX construct_idx2 on gene.construct (symbol);
CREATE INDEX construct_idx3 on gene.construct (insertion_id);
CREATE INDEX construct_idx4 on gene.construct (allele_id);
ALTER TABLE gene.construct ADD CONSTRAINT construct_fk1 FOREIGN KEY (insertion_id) REFERENCES gene.insertion (id);
ALTER TABLE gene.construct ADD CONSTRAINT construct_fk2 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);

/*
 * Tools that are related to either the construct or allele.
 */
DROP TABLE IF EXISTS gene.tool CASCADE;
CREATE TABLE gene.tool
  AS SELECT fbto_fbgn.uniquename AS fbid,
            fbto_fbgn.symbol AS symbol,
            fbto_fbgn.type as rel_type,
            fbtp.id as construct_id,
            NULL::bigint as allele_id
       FROM gene.construct AS fbtp JOIN feature f ON (fbtp.fbtp_id = f.uniquename)
                                   JOIN flybase.get_feature_relationship(fbtp.fbtp_id, 'has_reg_region|encodes_tool|carries_tool|tagged_with', 'FBto|FBgn', 'object') AS fbto_fbgn
                                     ON (f.feature_id = fbto.subject_id)
       UNION
       SELECT fbto_fbgn.uniquename AS fbid,
            fbto_fbgn.symbol AS symbol,
            fbto_fbgn.type as rel_type,
            NULL::bigint as construct_id,
            fbal.id as allele_id
         FROM gene.allele AS fbal JOIN feature f ON (fbal.fbal_id = f.uniquename)
                                  JOIN flybase.get_feature_relationship(fbal.fbal_id, 'has_reg_region|encodes_tool|carries_tool|tagged_with', 'FBto|FBgn', 'object') AS fbto_fbgn
                                    ON (f.feature_id = fbto_fbgn.subject_id)
;
ALTER TABLE gene.tool ADD COLUMN id SERIAL PRIMARY KEY;
CREATE INDEX tool_idx1 on gene.tool (fbid);
CREATE INDEX tool_idx2 on gene.tool (symbol);
CREATE INDEX tool_idx3 on gene.tool (rel_type);
CREATE INDEX tool_idx4 on gene.tool (construct_id);
CREATE INDEX tool_idx5 on gene.tool (allele_id);
ALTER TABLE gene.tool ADD CONSTRAINT tool_fk1 FOREIGN KEY (construct_id) REFERENCES gene.construct (id);
ALTER TABLE gene.tool ADD CONSTRAINT tool_fk2 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);

/* Tool Use */
DROP TABLE IF EXISTS gene.tool_use CASCADE;
CREATE TABLE gene.tool_use
  -- Get all tool_uses associated with the alleles.
  AS SELECT 
            cvt.name as name,
            db.name || ':' || dbx.accession as fbcv_id,
            fbal.id as allele_id,
            NULL::bigint as construct_id,
            NULL::bigint as tool_id
       FROM gene.allele fbal JOIN feature f ON (fbal.fbal_id = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
                             JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
                             JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
                             JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
       WHERE fcvtp_type.name = 'tool_uses'
     UNION
     SELECT 
            cvt.name as name,
            db.name || ':' || dbx.accession as fbcv_id,
            NULL::bigint as allele_id,
            fbtp.id as construct_id,
            NULL::bigint as tool_id
       FROM gene.construct fbtp JOIN feature f ON (fbtp.fbtp_id = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
                             JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
                             JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
                             JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
       WHERE fcvtp_type.name = 'tool_uses'
     UNION
     SELECT 
            cvt.name as name,
            db.name || ':' || dbx.accession as fbcv_id,
            NULL::bigint as allele_id,
            NULL::bigint as construct_id,
            fbto_fbgn.id as tool_id
       FROM gene.tool fbto_fbgn JOIN feature f ON (fbto_fbgn.fbid = f.uniquename)
                             JOIN feature_cvterm fcvt ON (f.feature_id = fcvt.feature_id)
                             JOIN feature_cvtermprop fcvtp on (fcvt.feature_cvterm_id = fcvtp.feature_cvterm_id)
                             JOIN cvterm fcvtp_type on (fcvtp.type_id = fcvtp_type.cvterm_id)
                             JOIN cvterm cvt on (fcvt.cvterm_id = cvt.cvterm_id)
                             JOIN dbxref dbx on (cvt.dbxref_id = dbx.dbxref_id)
                             JOIN db on (dbx.db_id = db.db_id)
       WHERE fcvtp_type.name = 'tool_uses'
;

ALTER TABLE gene.tool_use ADD COLUMN id SERIAL PRIMARY KEY;
CREATE INDEX tool_use_idx1 on gene.tool_use (fbcv_id);
CREATE INDEX tool_use_idx2 on gene.tool_use (name);
CREATE INDEX tool_use_idx3 on gene.tool_use (allele_id);
CREATE INDEX tool_use_idx4 on gene.tool_use (construct_id);
CREATE INDEX tool_use_idx5 on gene.tool_use (tool_id);
ALTER TABLE gene.tool_use ADD CONSTRAINT tool_use_fk1 FOREIGN KEY (allele_id) REFERENCES gene.allele (id);
ALTER TABLE gene.tool_use ADD CONSTRAINT tool_use_fk2 FOREIGN KEY (construct_id) REFERENCES gene.construct (id);
ALTER TABLE gene.tool_use ADD CONSTRAINT tool_use_fk3 FOREIGN KEY (tool_id) REFERENCES gene.tool (id);