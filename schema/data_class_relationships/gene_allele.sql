
DROP TABLE IF EXISTS dataclass_relationship.gene_allele CASCADE;

CREATE TABLE dataclass_relationship.gene_allele
AS
SELECT DISTINCT *
FROM (
	SELECT allele.uniquename AS allele_id,
		alleleof_gene.uniquename AS gene_id,
        (
       		EXISTS (
       			SELECT 1
       			FROM feature_relationship
       			JOIN feature
       				ON (
       					feature.feature_id = feature_relationship.object_id
       					AND feature.uniquename ~ '^FB(tp|mc|ms)[0-9]+$'
       					AND feature.is_analysis = FALSE
       					AND feature.is_obsolete = FALSE
       				)
   				JOIN cvterm
   					ON (
   						feature_relationship.type_id = cvterm.cvterm_id
						AND cvterm."name" = 'associated_with'
					)
   				WHERE feature_relationship.subject_id = allele.feature_id
       		)
       		OR EXISTS (
       			SELECT 1
       			FROM feature_cvterm
       			JOIN cvterm
       				ON (
       					feature_cvterm.cvterm_id = cvterm.cvterm_id
   						AND POSITION('in vitro construct' IN LOWER(cvterm."name")) = 1
   					)
   				JOIN cvtermprop
       				ON (
       					cvterm.cvterm_id = cvtermprop.cvterm_id
       					AND cvtermprop.value = 'origin_of_mutation'
   					)
				WHERE feature_cvterm.feature_id = allele.feature_id
			)
        ) AS is_construct
	FROM feature allele
	JOIN feature_relationship fr_ao
		ON allele.feature_id = fr_ao.subject_id
	JOIN cvterm cvt_fr_ao_type
		ON (
	        fr_ao.type_id = cvt_fr_ao_type.cvterm_id
	        AND cvt_fr_ao_type."name" = 'alleleof'
	    )
	JOIN feature alleleof_gene
		ON (
			fr_ao.object_id = alleleof_gene.feature_id
			AND alleleof_gene.uniquename ~ '^FBgn[0-9]+$'
			AND alleleof_gene.is_analysis = FALSE
			AND alleleof_gene.is_obsolete = FALSE
		)
    JOIN cvterm cvt_type
            ON (
                allele.type_id = cvt_type.cvterm_id
                AND cvt_type."name" = 'allele'
            )
	WHERE allele.uniquename ~ '^FBal[0-9]+$'
		AND allele.is_analysis = FALSE
		AND allele.is_obsolete = FALSE
UNION
	SELECT allele.uniquename AS allele_id,
		has_reg_region_gene.uniquename AS gene_id,
		TRUE AS is_construct
	FROM feature allele
	JOIN feature_relationship fr_ao
		ON allele.feature_id = fr_ao.subject_id
	JOIN cvterm cvt_fr_ao_type
		ON (
	        fr_ao.type_id = cvt_fr_ao_type.cvterm_id
	        AND cvt_fr_ao_type."name" = 'has_reg_region'
	    )
	JOIN feature has_reg_region_gene
		ON (
			fr_ao.object_id = has_reg_region_gene.feature_id
			AND has_reg_region_gene.uniquename ~ '^FBgn[0-9]+$'
			AND has_reg_region_gene.is_analysis = FALSE
			AND has_reg_region_gene.is_obsolete = FALSE
		)
    JOIN cvterm cvt_type
            ON (
                allele.type_id = cvt_type.cvterm_id
                AND cvt_type."name" = 'allele'
            )
	WHERE allele.uniquename ~ '^FBal[0-9]+$'
		AND allele.is_analysis = FALSE
		AND allele.is_obsolete = FALSE
UNION
	SELECT fbal.uniquename AS allele_id,
		fbgn.uniquename AS gene_id,
		TRUE AS is_construct
	FROM feature fbtr_fbpp
	-- Add fbtr_fbpp associated_with fbal
	JOIN feature_relationship fr_fbtr_fbpp_associated_with_fbal
		ON fbtr_fbpp.feature_id = fr_fbtr_fbpp_associated_with_fbal.subject_id
	JOIN cvterm cvt_fr_fbtr_fbpp_associated_with_fbal_type
		ON (
			fr_fbtr_fbpp_associated_with_fbal.type_id = cvt_fr_fbtr_fbpp_associated_with_fbal_type.cvterm_id
			AND	cvt_fr_fbtr_fbpp_associated_with_fbal_type."name" = 'associated_with'
		)
	JOIN feature fbal
		ON (
			fr_fbtr_fbpp_associated_with_fbal.object_id = fbal.feature_id
			AND fbal.uniquename ~ '^FBal[0-9]+$'
			AND fbal.is_analysis = FALSE
			AND fbal.is_obsolete = FALSE
		)
    JOIN cvterm cvt_type
            ON (
                fbal.type_id = cvt_type.cvterm_id
                AND cvt_type."name" = 'allele'
            )
	-- Add fbal associated_with fbtp
	JOIN feature_relationship fr_fbal_associated_with_fbtp
		ON fbal.feature_id = fr_fbal_associated_with_fbtp.subject_id
	JOIN cvterm cvt_fr_fbal_associated_with_fbtp_type
		ON (
			fr_fbal_associated_with_fbtp.type_id = cvt_fr_fbal_associated_with_fbtp_type.cvterm_id
			AND	cvt_fr_fbal_associated_with_fbtp_type."name" = 'associated_with'
		)
	JOIN feature fbtp
		ON (
			fr_fbal_associated_with_fbtp.object_id = fbtp.feature_id
			AND fbtp.uniquename ~ '^FBtp[0-9]+$'
			AND fbtp.is_analysis = FALSE
			AND fbtp.is_obsolete = FALSE
		)
	-- Add fbal encodes_tool fbto
	JOIN feature_relationship fr_fbal_encodes_tool_fbtp
		ON fbal.feature_id = fr_fbal_encodes_tool_fbtp.subject_id
	JOIN cvterm cvt_fr_fbal_encodes_tool_fbtp_type
		ON (
			fr_fbal_encodes_tool_fbtp.type_id = cvt_fr_fbal_encodes_tool_fbtp_type.cvterm_id
			AND	cvt_fr_fbal_encodes_tool_fbtp_type."name" = 'encodes_tool'
		)
	JOIN feature fbto
		ON (
			fr_fbal_encodes_tool_fbtp.object_id = fbto.feature_id
			AND fbto.uniquename ~ '^FBto[0-9]+$'
			AND fbto.is_analysis = FALSE
			AND fbto.is_obsolete = FALSE
		)
	-- Add fbtr_fbpp attributed_as_expression_of fbgn
	JOIN feature_relationship fr_fbtr_fbpp_attributed_as_expression_of_fbgn
		ON fbal.feature_id = fr_fbtr_fbpp_attributed_as_expression_of_fbgn.subject_id
	JOIN cvterm cvt_fr_fbtr_fbpp_attributed_as_expression_of_fbgn_type
		ON (
			fr_fbtr_fbpp_attributed_as_expression_of_fbgn.type_id = cvt_fr_fbtr_fbpp_attributed_as_expression_of_fbgn_type.cvterm_id
			AND	cvt_fr_fbtr_fbpp_attributed_as_expression_of_fbgn_type."name" = 'attributed_as_expression_of'
		)
	JOIN feature fbgn
		ON (
			fr_fbtr_fbpp_attributed_as_expression_of_fbgn.object_id = fbgn.feature_id
			AND fbgn.uniquename ~ '^FBgn[0-9]+$'
			AND fbgn.is_analysis = FALSE
			AND fbgn.is_obsolete = FALSE
		)
	WHERE fbtr_fbpp.uniquename ~ '^FB(tr|pp)[0-9]+$'
		AND fbtr_fbpp.is_analysis = FALSE
		AND fbtr_fbpp.is_obsolete = FALSE
UNION
	SELECT allele.uniquename AS allele_id,
		aw_gene.uniquename AS gene_id,
		TRUE AS is_construct
	FROM feature allele
	JOIN feature_relationship fr_hrr
		ON allele.feature_id = fr_hrr.subject_id
	JOIN cvterm cvt_fr_hrr_type
		ON (
	        fr_hrr.type_id = cvt_fr_hrr_type.cvterm_id
	        AND cvt_fr_hrr_type."name" = 'has_reg_region'
	    )
	JOIN feature has_reg_region_fbsf
		ON (
			fr_hrr.object_id = has_reg_region_fbsf.feature_id
			AND has_reg_region_fbsf.uniquename ~ '^FBsf[0-9]+$'
			AND has_reg_region_fbsf.is_analysis = FALSE
			AND has_reg_region_fbsf.is_obsolete = FALSE
		)
	JOIN feature_relationship fr_aw
		ON has_reg_region_fbsf.feature_id = fr_aw.subject_id
	JOIN cvterm cvt_fr_aw_type
		ON (
	        fr_aw.type_id = cvt_fr_aw_type.cvterm_id
	        AND cvt_fr_aw_type."name" = 'associated_with'
	    )
	JOIN feature aw_gene
		ON (
			fr_aw.object_id = aw_gene.feature_id
			AND aw_gene.uniquename ~ '^FBgn[0-9]+$'
			AND aw_gene.is_analysis = FALSE
			AND aw_gene.is_obsolete = FALSE
		)
    JOIN cvterm cvt_type
        ON (
            allele.type_id = cvt_type.cvterm_id
            AND cvt_type."name" = 'allele'
        )
	WHERE allele.uniquename ~ '^FBal[0-9]+$'
		AND allele.is_analysis = FALSE
		AND allele.is_obsolete = FALSE
) AS subquery
;

ALTER TABLE dataclass_relationship.gene_allele ADD PRIMARY KEY (gene_id, allele_id, is_construct);

ALTER TABLE dataclass_relationship.gene_allele
    ADD CONSTRAINT gene_allele_fk1
    FOREIGN KEY (gene_id) REFERENCES dataclass.gene (id);
ALTER TABLE dataclass_relationship.gene_allele
    ADD CONSTRAINT gene_allele_fk2
    FOREIGN KEY (allele_id) REFERENCES dataclass.allele (id);

CREATE INDEX gene_allele_idx1 ON dataclass_relationship.gene_allele (gene_id);
CREATE INDEX gene_allele_idx2 ON dataclass_relationship.gene_allele (allele_id);
CREATE INDEX gene_allele_idx3 ON dataclass_relationship.gene_allele (is_construct);
