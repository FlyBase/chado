

-- Adding is_obsolete column until https://github.com/GMOD/Chado/pull/111
-- is merged into GMOD Chado proper and then FlyBase.
ALTER TABLE cell_line ADD COLUMN is_obsolete boolean DEFAULT false NOT NULL;