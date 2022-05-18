CREATE SCHEMA IF NOT EXISTS datasets;

-- Drop table
DROP TABLE IF EXISTS datasets.dataset cascade;

-- Create an adjacency list table to hold the hierachical dataset structure.
CREATE TABLE datasets.dataset
  AS SELECT
           -- Dataset ID (FBlc)
           fblc.uniquename AS fblc_id,
           -- Dataset symbol
           fblc.name AS symbol,
           fblc.library_id AS library_id,
           parentlc.uniquename AS parent_id,
           parentlc.relationship_type AS rel_type
         FROM public.library AS fblc LEFT JOIN
            ( SELECT lr.subject_id, object.uniquename, lr_type.name AS relationship_type
              FROM library object JOIN library_relationship lr ON object.library_id = lr.object_id AND object.is_obsolete = false
                                  JOIN cvterm lr_type ON lr.type_id = lr_type.cvterm_id AND lr_type.name NOT LIKE 'derived_%'
            ) AS parentlc
            ON fblc.library_id = parentlc.subject_id
         WHERE fblc.is_obsolete = false;
;

ALTER TABLE datasets.dataset ADD COLUMN uid SERIAL PRIMARY KEY;

/*
Returns a set of library table rows that represent the leaf nodes 
of a FlyBase dataset that are connected to a gene. Datasets use a
graph structure to represent projects, biosamples, assays, results,
etc. This function finds all leaf nodes in this graph when given a single
FBgn ID.

@param id - FlyBase FBgn ID
@return   - Set of library rows.
*/
CREATE OR REPLACE FUNCTION datasets.dataset_leaf_nodes_by_gene(id text)
    RETURNS SETOF library AS 
$$
SELECT DISTINCT fblc.*
    FROM library fblc JOIN library_feature lf ON fblc.library_id = lf.library_id
                      JOIN gene.gene fbgn ON lf.feature_id = fbgn.feature_id
                      JOIN datasets.dataset ON fblc.library_id = datasets.dataset.library_id
    WHERE fblc.is_obsolete = false
      AND fbgn.uniquename = $1
      AND fblc.uniquename != datasets.dataset.parent_id
  ;
$$ LANGUAGE SQL STABLE;

DROP TYPE IF EXISTS datasets.dataset_node CASCADE;
-- Type used to represent a node in the dataset adjacency list.
CREATE TYPE datasets.dataset_node AS (
  fblc_id text,
  library_id integer,
  symbol varchar(255),
  parent_id text,
  rel_type varchar(1024)
);

/*
Returns a set of table rows with FBlc ID, library.library_id, FBlc symbol, parent FBlc ID, and relationship type
that represent all ancestors of the given FBlc ID.

When given a leaf node, the table returned represents an adjacency list of the dataset relationship graph from the
bottom node all the way to the root dataset.

@param id - The FBlc ID of the leaf node.
@return   - Temporary table with FBlc ID, library.library_id, FBlc symbol, parent FBlc ID, and relationship type.

*/
CREATE OR REPLACE FUNCTION datasets.ancestors(id text)
    RETURNS SETOF datasets.dataset_node AS
$$
BEGIN
  -- Common table expression to discover all ancestor nodes of a given FBlc.
RETURN QUERY WITH RECURSIVE dataset_ancestors(fblc_id, library_id, symbol, parent_id, rel_type) AS (
    SELECT fblc.fblc_id, fblc.library_id, fblc.symbol, fblc.parent_id, fblc.rel_type
      FROM datasets.dataset fblc
      WHERE fblc.fblc_id = $1
    UNION
      SELECT fblc.fblc_id, fblc.library_id, fblc.symbol, fblc.parent_id, fblc.rel_type
        FROM dataset_ancestors da JOIN datasets.dataset fblc ON (da.parent_id = fblc.fblc_id)
  )
  SELECT * from dataset_ancestors;
END;
$$ LANGUAGE plpgsql STABLE;

/*
Returns an adjacency list containing dataset nodes that describe the 
graph structure of the datasets related to the given FBgn ID.

In a relational form, the adjacency list has a form of

e.g.
FBlc ID   | Parent FBlc
========================
FBlc12341 | FBlc12340
FBlc12341 | FBlc12342
FBlc12342 | FBlc12340

In a non relational environment, this adjacency list is often collapsed into the form.

FBlc ID   | Parent FBlc
========================
FBlc12341 | [FBlc12340, FBlc12342]
FBlc12342 | FBlc12340

This structure can be used to reconstruct / traverse the FBlc graph.

@param id - The FBgn ID of the gene.
@return   - Set of dataset_node 

*/
CREATE OR REPLACE FUNCTION datasets.dataset_graph_by_gene(id text)
    RETURNS SETOF datasets.dataset_node AS
$$
SELECT DISTINCT anc.*
  -- Use an implicit lateral join query to fetch the list of all leaf nodes for the FBgn
  -- and then get all ancestors.
  FROM datasets.dataset_leaf_nodes_by_gene($1) fblc,
       datasets.ancestors(fblc.uniquename) as anc
;
$$ LANGUAGE SQL STABLE;


